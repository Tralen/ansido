-- | Domain types and pure transitions for the task board.
--
-- Every value here is immutable. Transitions return a new 'Workspace' and
-- report failures as data through 'DomainError'.
module Ansido.Domain
  ( -- * Identifiers and text.
    CategoryId (..)
  , CategoryName (..)
  , TaskId (..)
  , TaskTitle (..)
  , TaskContent (..)
    -- * Entities.
  , Category (..)
  , Status (..)
  , Task (..)
  , Workspace
    -- * Errors.
  , DomainError (..)
  , domainErrorMessage
    -- * Construction.
  , emptyWorkspace
  , mkCategoryName
  , mkTaskTitle
  , mkTaskContent
  , mkWorkspace
    -- * Queries.
  , workspaceCategories
  , workspaceTasks
  , findCategory
  , findTask
  , categoryTasks
  , tasksByStatus
  , taskCount
  , statusLabel
  , statusKey
  , statusFromKey
  , nextStatus
  , indexMaybe
    -- * Transitions.
  , addCategory
  , addTask
  , moveTask
  , advanceTask
  , editTask
  , deleteTask
  ) where

--------------------------------------------------------------------------------
import           Data.Char (isControl, isSpace)
import           Data.List (dropWhileEnd, find, nub, sort)
import           Data.Maybe (listToMaybe)

-- Identifiers.
--------------------------------------------------------------------------------

-- | Stable identifier of a category.
newtype CategoryId = CategoryId { categoryIdValue :: Int }
  deriving (Eq, Ord, Show)

-- | Validated name of a category.
newtype CategoryName = CategoryName { categoryNameText :: String }
  deriving (Eq, Ord, Show)

-- | Stable identifier of a task.
newtype TaskId = TaskId { taskIdValue :: Int }
  deriving (Eq, Ord, Show)

-- | Validated title of a task.
newtype TaskTitle = TaskTitle { taskTitleText :: String }
  deriving (Eq, Ord, Show)

-- | Validated note attached to a task. It may be empty.
newtype TaskContent = TaskContent { taskContentText :: String }
  deriving (Eq, Ord, Show)

-- Entities.
--------------------------------------------------------------------------------

-- | A category groups tasks and scopes the board.
data Category = Category
  { categoryId   :: CategoryId
  , categoryName :: CategoryName
  } deriving (Eq, Show)

-- | The three columns of the board.
data Status = Todo | Doing | Done
  deriving (Eq, Ord, Show)

-- | A task with a title, a note, a status and the category that owns it.
data Task = Task
  { taskId       :: TaskId
  , taskTitle    :: TaskTitle
  , taskContent  :: TaskContent
  , taskStatus   :: Status
  , taskCategory :: CategoryId
  } deriving (Eq, Show)

-- | The whole persisted state, with hidden constructors to keep invariants.
data Workspace = Workspace
  { workspaceCategories :: [Category]
  , workspaceTasks      :: [Task]
  } deriving (Eq, Show)

--------------------------------------------------------------------------------

-- | Human readable label of a status.
statusLabel :: Status -> String
statusLabel Todo  = "Todo"
statusLabel Doing = "Doing"
statusLabel Done  = "Done"

-- | Stable key used by the persistence format.
statusKey :: Status -> String
statusKey Todo  = "todo"
statusKey Doing = "doing"
statusKey Done  = "done"

-- | Parses a stable status key.
statusFromKey :: String -> Maybe Status
statusFromKey key =
  case key of
    "todo"  -> Just Todo
    "doing" -> Just Doing
    "done"  -> Just Done
    _       -> Nothing

-- | The next status in the cycle used by the state key.
nextStatus :: Status -> Status
nextStatus Todo  = Doing
nextStatus Doing = Done
nextStatus Done  = Todo

--------------------------------------------------------------------------------

-- | A workspace with no categories and no tasks.
emptyWorkspace :: Workspace
emptyWorkspace = Workspace [] []

-- | Validates a category name.
mkCategoryName :: String -> Either DomainError CategoryName
mkCategoryName raw =
  CategoryName <$> validateText EmptyCategoryName categoryNameLimit
                                CategoryNameTooLong raw

-- | Validates a task title.
mkTaskTitle :: String -> Either DomainError TaskTitle
mkTaskTitle raw =
  TaskTitle <$> validateText EmptyTaskTitle taskTitleLimit
                            TaskTitleTooLong raw

-- | Validates a task note. An empty note is allowed.
mkTaskContent :: String -> Either DomainError TaskContent
mkTaskContent raw =
  let cleaned = trim raw
  in if any isControl cleaned
       then Left ControlCharacterInText
       else if length cleaned > taskContentLimit
         then Left (TaskContentTooLong taskContentLimit)
         else Right (TaskContent cleaned)

validateText :: DomainError -> Int -> (Int -> DomainError) -> String
             -> Either DomainError String
validateText emptyError limit tooLongError raw =
  let cleaned = trim raw
  in if null cleaned
       then Left emptyError
       else if any isControl cleaned
         then Left ControlCharacterInText
         else if length cleaned > limit
           then Left (tooLongError limit)
           else Right cleaned

-- | Checks the workspace invariants.
--
-- Categories must have unique identifiers and names, tasks must have unique
-- identifiers and every task must point at an existing category.
mkWorkspace :: [Category] -> [Task] -> Either DomainError Workspace
mkWorkspace categories tasks
  | hasDuplicate (map categoryId categories)   = Left DuplicateCategoryId
  | hasDuplicate (map categoryName categories) = Left DuplicateCategoryName
  | hasDuplicate (map taskId tasks)            = Left DuplicateTaskId
  | otherwise =
      case firstUnknownCategory categories tasks of
        Just unknown -> Left (UnknownCategory unknown)
        Nothing      -> Right (Workspace categories tasks)
  where
    hasDuplicate values = length values /= length (nub (sort values))

firstUnknownCategory :: [Category] -> [Task] -> Maybe CategoryId
firstUnknownCategory categories tasks =
  listToMaybe (map taskCategory (filter unknown tasks))
  where
    unknown task = not (any ((== taskCategory task) . categoryId) categories)

--------------------------------------------------------------------------------

-- | Finds a category by identifier.
findCategory :: CategoryId -> Workspace -> Maybe Category
findCategory identifier =
  find ((== identifier) . categoryId) . workspaceCategories

-- | Finds a task by identifier.
findTask :: TaskId -> Workspace -> Maybe Task
findTask identifier =
  find ((== identifier) . taskId) . workspaceTasks

-- | Tasks of a category, in insertion order.
categoryTasks :: CategoryId -> Workspace -> [Task]
categoryTasks identifier =
  filter ((== identifier) . taskCategory) . workspaceTasks

-- | Tasks with a given status, preserving the input order.
tasksByStatus :: Status -> [Task] -> [Task]
tasksByStatus status = filter ((== status) . taskStatus)

-- | Number of tasks in a category and status.
taskCount :: CategoryId -> Status -> Workspace -> Int
taskCount identifier status =
  length . tasksByStatus status . categoryTasks identifier

-- | Safe list indexing, used instead of the partial '!!' operator.
indexMaybe :: Int -> [a] -> Maybe a
indexMaybe index values
  | index < 0 = Nothing
  | otherwise =
      case drop index values of
        (value : _) -> Just value
        []          -> Nothing

--------------------------------------------------------------------------------

-- | Adds a category and returns it together with the new workspace.
addCategory :: CategoryName -> Workspace -> Either DomainError (Category, Workspace)
addCategory name workspace
  | any ((== name) . categoryName) (workspaceCategories workspace) =
      Left (CategoryAlreadyExists name)
  | otherwise =
      let category = Category (nextCategoryId workspace) name
      in do
        updated <- mkWorkspace
          (workspaceCategories workspace <> [category])
          (workspaceTasks workspace)
        Right (category, updated)

-- | Adds a task to a category, always starting at 'Todo'.
addTask :: CategoryId -> TaskTitle -> TaskContent -> Workspace
        -> Either DomainError (Task, Workspace)
addTask identifier title content workspace
  | not (any ((== identifier) . categoryId) (workspaceCategories workspace)) =
      Left (UnknownCategory identifier)
  | otherwise =
      let task = Task (nextTaskId workspace) title content Todo identifier
      in do
        updated <- mkWorkspace
          (workspaceCategories workspace)
          (workspaceTasks workspace <> [task])
        Right (task, updated)

-- | Sets the status of a task.
moveTask :: TaskId -> Status -> Workspace -> Either DomainError Workspace
moveTask identifier status workspace =
  case findTask identifier workspace of
    Nothing -> Left (UnknownTask identifier)
    Just _  ->
      mkWorkspace
        (workspaceCategories workspace)
        (replaceStatus identifier status (workspaceTasks workspace))

replaceStatus :: TaskId -> Status -> [Task] -> [Task]
replaceStatus identifier status =
  map update
  where
    update task
      | taskId task == identifier = task { taskStatus = status }
      | otherwise                 = task

-- | Moves a task to the next status in the cycle.
advanceTask :: TaskId -> Workspace -> Either DomainError Workspace
advanceTask identifier workspace =
  case findTask identifier workspace of
    Nothing   -> Left (UnknownTask identifier)
    Just task -> moveTask identifier (nextStatus (taskStatus task)) workspace

-- | Replaces the title and note of a task.
editTask :: TaskId -> TaskTitle -> TaskContent -> Workspace
         -> Either DomainError Workspace
editTask identifier title content workspace =
  case findTask identifier workspace of
    Nothing -> Left (UnknownTask identifier)
    Just _  ->
      mkWorkspace
        (workspaceCategories workspace)
        (map update (workspaceTasks workspace))
  where
    update task
      | taskId task == identifier =
          task { taskTitle = title, taskContent = content }
      | otherwise = task

-- | Removes a task.
deleteTask :: TaskId -> Workspace -> Either DomainError Workspace
deleteTask identifier workspace =
  if any ((== identifier) . taskId) (workspaceTasks workspace)
    then mkWorkspace
      (workspaceCategories workspace)
      (filter ((/= identifier) . taskId) (workspaceTasks workspace))
    else Left (UnknownTask identifier)

nextCategoryId :: Workspace -> CategoryId
nextCategoryId workspace =
  CategoryId (nextIdentifier (categoryIdValue . categoryId)
                            (workspaceCategories workspace))

nextTaskId :: Workspace -> TaskId
nextTaskId workspace =
  TaskId (nextIdentifier (taskIdValue . taskId) (workspaceTasks workspace))

nextIdentifier :: (a -> Int) -> [a] -> Int
nextIdentifier get values = 1 + foldr (max . get) 0 values

--------------------------------------------------------------------------------

-- | Failures of domain construction and transitions.
data DomainError
  = EmptyCategoryName
  | EmptyTaskTitle
  | CategoryNameTooLong Int
  | TaskTitleTooLong Int
  | TaskContentTooLong Int
  | ControlCharacterInText
  | UnknownCategory CategoryId
  | UnknownTask TaskId
  | DuplicateCategoryId
  | DuplicateTaskId
  | DuplicateCategoryName
  | CategoryAlreadyExists CategoryName
  deriving (Eq, Show)

-- | English message for a domain error.
domainErrorMessage :: DomainError -> String
domainErrorMessage err =
  case err of
    EmptyCategoryName -> "The category name cannot be empty."
    EmptyTaskTitle -> "The task title cannot be empty."
    CategoryNameTooLong limit ->
      "The category name must have at most " <> show limit <> " characters."
    TaskTitleTooLong limit ->
      "The task title must have at most " <> show limit <> " characters."
    TaskContentTooLong limit ->
      "The task note must have at most " <> show limit <> " characters."
    ControlCharacterInText ->
      "The text cannot contain control characters."
    UnknownCategory identifier ->
      "Unknown category: " <> show (categoryIdValue identifier) <> "."
    UnknownTask identifier ->
      "Unknown task: " <> show (taskIdValue identifier) <> "."
    DuplicateCategoryId -> "Two categories share the same identifier."
    DuplicateTaskId -> "Two tasks share the same identifier."
    DuplicateCategoryName -> "Two categories share the same name."
    CategoryAlreadyExists name ->
      "The category already exists: " <> categoryNameText name <> "."

--------------------------------------------------------------------------------

categoryNameLimit :: Int
categoryNameLimit = 40

taskTitleLimit :: Int
taskTitleLimit = 120

taskContentLimit :: Int
taskContentLimit = 500

trim :: String -> String
trim = dropWhileEnd isSpace . dropWhile isSpace
