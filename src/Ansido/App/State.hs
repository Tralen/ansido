-- | Application state and the actions that can change it.
module Ansido.App.State
  ( Screen (..)
  , Filter (..)
  , RowIndex (..)
  , UiState (..)
  , AppState (..)
  , Direction (..)
  , Action (..)
  , initialAppState
  , initialUiState
  , withDataFile
  , currentCategory
  , visibleTasks
  , selectedTaskId
  , selectedTask
  , filterTasks
  , filterLabel
  , nextFilter
  , withNotice
  ) where

--------------------------------------------------------------------------------
import           Data.Maybe (listToMaybe)

import           Ansido.Domain
import           Ansido.Ui.Components (Notice)

-- | Which screen is currently visible.
data Screen
  = BoardScreen
  | DetailsScreen TaskId
  | EditTaskScreen TaskId
  | HelpScreen
  | CategoryScreen
  | AddTaskScreen
  | AddCategoryScreen
  | EditCategoryScreen CategoryId
  deriving (Eq, Show)

-- | Zero based position inside the task table.
newtype RowIndex = RowIndex { rowIndexValue :: Int }
  deriving (Eq, Ord, Show)

-- | Which states the table shows. 'ShowAll' disables the filter.
data Filter = ShowAll | OnlyStatus Status
  deriving (Eq, Show)

-- | Everything the interface needs besides the workspace.
data UiState = UiState
  { uiScreen   :: Screen
  , uiCategory :: Maybe CategoryId
  , uiFilter   :: Filter
  , uiRow      :: RowIndex
  , uiNotice   :: Maybe Notice
  } deriving (Eq, Show)

-- | The whole application state.
data AppState = AppState
  { appWorkspace :: Workspace
  , appUi        :: UiState
  , appDataFile  :: FilePath
  } deriving (Eq, Show)

-- | Direction of a discrete movement.
data Direction = Previous | Next
  deriving (Eq, Show)

-- | Every state change requested by the interface, handled by a pure update.
data Action
  = OpenBoard
  | OpenHelp
  | OpenCategories
  | OpenDetails
  | OpenEditTask
  | OpenAddTask
  | OpenAddCategory
  | OpenEditCategory
  | SelectCategory CategoryId
  | MoveRow Direction
  | CycleFilter
  | CycleSelected
  | DeleteSelected
  | DeleteSelectedCategory
  | SubmitTask String String
  | SubmitEdit TaskId String String
  | SubmitCategory String
  | SubmitCategoryEdit CategoryId String
  | SetNotice Notice
  | ClearNotice
  deriving (Eq, Show)

-- | Builds the initial state on the category screen.
initialAppState :: Workspace -> AppState
initialAppState workspace =
  AppState
    { appWorkspace = workspace
    , appUi = initialUiState workspace
    , appDataFile = ""
    }

-- | Records the data file path shown on the help screen.
withDataFile :: FilePath -> AppState -> AppState
withDataFile path app =
  app { appDataFile = path }

-- | Initial interface state, always starting on the category screen.
initialUiState :: Workspace -> UiState
initialUiState workspace =
  UiState
    { uiScreen = CategoryScreen
    , uiCategory = fmap categoryId (listToMaybe (workspaceCategories workspace))
    , uiFilter = ShowAll
    , uiRow = RowIndex 0
    , uiNotice = Nothing
    }

-- | The selected category, when one exists.
currentCategory :: AppState -> Maybe Category
currentCategory app =
  uiCategory (appUi app) >>= \identifier ->
    findCategory identifier (appWorkspace app)

-- | Tasks visible in the selected category, in insertion order.
visibleTasks :: AppState -> [Task]
visibleTasks app =
  case uiCategory (appUi app) of
    Nothing -> []
    Just identifier ->
      filterTasks (uiFilter (appUi app))
        (categoryTasks identifier (appWorkspace app))

-- | Applies the state filter to a list of tasks.
filterTasks :: Filter -> [Task] -> [Task]
filterTasks ShowAll = id
filterTasks (OnlyStatus status) = tasksByStatus status

-- | Human readable label of a filter.
filterLabel :: Filter -> String
filterLabel ShowAll = "all"
filterLabel (OnlyStatus status) = statusLabel status

-- | Advances the filter through all, Todo, Doing and Done.
nextFilter :: Filter -> Filter
nextFilter ShowAll = OnlyStatus Todo
nextFilter (OnlyStatus Todo) = OnlyStatus Doing
nextFilter (OnlyStatus Doing) = OnlyStatus Done
nextFilter (OnlyStatus Done) = ShowAll

-- | Task under the cursor, or the task open on the details or edit screen.
selectedTaskId :: AppState -> Maybe TaskId
selectedTaskId app =
  case uiScreen (appUi app) of
    DetailsScreen identifier -> Just identifier
    EditTaskScreen identifier -> Just identifier
    _ ->
      taskId <$> indexMaybe (rowIndexValue (uiRow (appUi app)))
                         (visibleTasks app)

-- | Task under the cursor, when it still exists.
selectedTask :: AppState -> Maybe Task
selectedTask app =
  selectedTaskId app >>= \identifier ->
    findTask identifier (appWorkspace app)

-- | Replaces the current notice.
withNotice :: Notice -> AppState -> AppState
withNotice notice app =
  app { appUi = (appUi app) { uiNotice = Just notice } }
