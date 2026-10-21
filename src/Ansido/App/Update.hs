-- | Pure update of the application state.
--
-- 'update' never touches the terminal. It either returns a new state or a
-- 'DomainError', which the runner turns into a notice on screen.
module Ansido.App.Update
  ( update
  , clampAppState
  ) where

--------------------------------------------------------------------------------
import           Data.Maybe (listToMaybe)

import           Ansido.App.State
import           Ansido.Domain
import           Ansido.Ui.Components (Notice (..), NoticeKind (..))

-- | Applies one action to the state.
update :: Action -> AppState -> Either DomainError AppState
update action app =
  case action of
    OpenBoard -> Right (setScreen BoardScreen app)
    OpenHelp -> Right (setScreen HelpScreen app)
    OpenCategories -> Right (setScreen CategoryScreen app)
    OpenDetails -> openDetails app
    OpenAddTask -> openAddTask app
    OpenAddCategory -> Right (setScreen AddCategoryScreen app)
    SelectCategory identifier -> selectCategory identifier app
    FocusStatus status -> Right (clampAppState (setStatus status app))
    MoveColumn direction -> Right (clampAppState (moveColumn direction app))
    MoveRow direction -> Right (moveRow direction app)
    AdvanceSelected -> advanceSelected app
    DeleteSelected -> deleteSelected app
    SubmitTask rawTitle -> submitTask rawTitle app
    SubmitCategory rawName -> submitCategory rawName app
    SetNotice notice -> Right (withNotice notice app)
    ClearNotice -> Right (clearNotice app)

-- Screens.
--------------------------------------------------------------------------------

setScreen :: Screen -> AppState -> AppState
setScreen screen app =
  clampAppState (app
    { appUi = (appUi app) { uiScreen = screen, uiNotice = Nothing } })

clearNotice :: AppState -> AppState
clearNotice app =
  app { appUi = (appUi app) { uiNotice = Nothing } }

openDetails :: AppState -> Either DomainError AppState
openDetails app =
  case selectedTask app of
    Just task ->
      Right (setScreen (DetailsScreen (taskId task)) app)
    Nothing ->
      Right (withNotice (Notice NoticeInfo "No task selected.") app)

openAddTask :: AppState -> Either DomainError AppState
openAddTask app =
  case uiCategory (appUi app) of
    Just _ -> Right (setScreen AddTaskScreen app)
    Nothing ->
      Right (withNotice (Notice NoticeError "Create a category first.") app)

selectCategory :: CategoryId -> AppState -> Either DomainError AppState
selectCategory identifier app
  | any ((== identifier) . categoryId) (workspaceCategories (appWorkspace app)) =
      Right (clampAppState (app
        { appUi = (appUi app)
            { uiScreen = BoardScreen
            , uiCategory = Just identifier
            , uiStatus = Todo
            , uiRow = RowIndex 0
            , uiNotice = Nothing
            }
        }))
  | otherwise = Left (UnknownCategory identifier)

-- Selection.
--------------------------------------------------------------------------------

setStatus :: Status -> AppState -> AppState
setStatus status app =
  app { appUi = (appUi app) { uiStatus = status } }

moveColumn :: Direction -> AppState -> AppState
moveColumn direction app =
  let delta = case direction of
        Previous -> -1
        Next     -> 1
      status = shiftStatus delta (uiStatus (appUi app))
  in setStatus status app

moveRow :: Direction -> AppState -> AppState
moveRow direction app =
  let current = rowIndexValue (uiRow (appUi app))
      limit = max 0 (length (visibleTasks app) - 1)
      next = case direction of
        Previous -> max 0 (current - 1)
        Next     -> min limit (current + 1)
  in app { appUi = (appUi app) { uiRow = RowIndex next } }

-- Tasks.
--------------------------------------------------------------------------------

advanceSelected :: AppState -> Either DomainError AppState
advanceSelected app =
  case selectedTask app of
    Nothing ->
      Right (withNotice (Notice NoticeInfo "No task selected.") app)
    Just task -> do
      workspace <- advanceTask (taskId task) (appWorkspace app)
      let next = nextStatus (taskStatus task)
          notice = Notice NoticeInfo ("Moved to " <> statusLabel next <> ".")
      Right (clampAppState (app
        { appWorkspace = workspace
        , appUi = (appUi app) { uiNotice = Just notice }
        }))

deleteSelected :: AppState -> Either DomainError AppState
deleteSelected app =
  case selectedTask app of
    Nothing ->
      Right (withNotice (Notice NoticeInfo "No task selected.") app)
    Just task -> do
      workspace <- deleteTask (taskId task) (appWorkspace app)
      Right (clampAppState (app
        { appWorkspace = workspace
        , appUi = (appUi app)
            { uiScreen = BoardScreen
            , uiNotice = Just (Notice NoticeInfo "Task deleted.")
            }
        }))

submitTask :: String -> AppState -> Either DomainError AppState
submitTask rawTitle app =
  case uiCategory (appUi app) of
    Nothing ->
      Right (withNotice (Notice NoticeError "Create a category first.") app)
    Just identifier -> do
      title <- mkTaskTitle rawTitle
      (task, workspace) <- addTask identifier title (appWorkspace app)
      let todoTasks = tasksByStatus (taskStatus task)
                        (categoryTasks identifier workspace)
          position = max 0 (length todoTasks - 1)
          notice = Notice NoticeInfo
            ("Task added: " <> taskTitleText title)
      Right (clampAppState (app
        { appWorkspace = workspace
        , appUi = (appUi app)
            { uiScreen = BoardScreen
            , uiCategory = Just identifier
            , uiStatus = taskStatus task
            , uiRow = RowIndex position
            , uiNotice = Just notice
            }
        }))

-- Categories.
--------------------------------------------------------------------------------

submitCategory :: String -> AppState -> Either DomainError AppState
submitCategory rawName app = do
  name <- mkCategoryName rawName
  (category, workspace) <- addCategory name (appWorkspace app)
  let notice = Notice NoticeInfo
        ("Category created: " <> categoryNameText name)
  Right (app
    { appWorkspace = workspace
    , appUi = (appUi app)
        { uiScreen = CategoryScreen
        , uiCategory = Just (categoryId category)
        , uiStatus = Todo
        , uiRow = RowIndex 0
        , uiNotice = Just notice
        }
    })

-- Clamping.
--------------------------------------------------------------------------------

-- | Restores selection invariants after a workspace or screen change.
clampAppState :: AppState -> AppState
clampAppState app =
  app { appUi = clampUiState (appWorkspace app) (appUi app) }

clampUiState :: Workspace -> UiState -> UiState
clampUiState workspace ui =
  let identifier = validCategory workspace (uiCategory ui)
      tasks = case identifier of
        Nothing -> []
        Just categoryIdentifier ->
          tasksByStatus (uiStatus ui)
            (categoryTasks categoryIdentifier workspace)
      limit = max 0 (length tasks - 1)
      position = min (max 0 (rowIndexValue (uiRow ui))) limit
  in ui
      { uiCategory = identifier
      , uiRow = RowIndex position
      }

validCategory :: Workspace -> Maybe CategoryId -> Maybe CategoryId
validCategory workspace Nothing =
  fmap categoryId (listToMaybe (workspaceCategories workspace))
validCategory workspace (Just identifier) =
  case findCategory identifier workspace of
    Just _  -> Just identifier
    Nothing -> fmap categoryId (listToMaybe (workspaceCategories workspace))
