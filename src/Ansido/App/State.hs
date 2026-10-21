-- | Application state and the actions that can change it.
module Ansido.App.State
  ( Screen (..)
  , RowIndex (..)
  , UiState (..)
  , AppState (..)
  , Direction (..)
  , Action (..)
  , initialAppState
  , initialUiState
  , currentCategory
  , visibleTasks
  , selectedTaskId
  , selectedTask
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
  | HelpScreen
  | CategoryScreen
  | AddTaskScreen
  | AddCategoryScreen
  deriving (Eq, Show)

-- | Zero based position inside the selected column.
newtype RowIndex = RowIndex { rowIndexValue :: Int }
  deriving (Eq, Ord, Show)

-- | Everything the interface needs besides the workspace.
data UiState = UiState
  { uiScreen   :: Screen
  , uiCategory :: Maybe CategoryId
  , uiStatus   :: Status
  , uiRow      :: RowIndex
  , uiNotice   :: Maybe Notice
  } deriving (Eq, Show)

-- | The whole application state.
data AppState = AppState
  { appWorkspace :: Workspace
  , appUi        :: UiState
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
  | OpenAddTask
  | OpenAddCategory
  | SelectCategory CategoryId
  | FocusStatus Status
  | MoveColumn Direction
  | MoveRow Direction
  | AdvanceSelected
  | DeleteSelected
  | SubmitTask String
  | SubmitCategory String
  | SetNotice Notice
  | ClearNotice
  deriving (Eq, Show)

-- | Builds the initial state, selecting the first category and the Todo column.
initialAppState :: Workspace -> AppState
initialAppState workspace =
  AppState
    { appWorkspace = workspace
    , appUi = initialUiState workspace
    }

-- | Initial interface state for a workspace.
initialUiState :: Workspace -> UiState
initialUiState workspace =
  UiState
    { uiScreen = BoardScreen
    , uiCategory = fmap categoryId (listToMaybe (workspaceCategories workspace))
    , uiStatus = Todo
    , uiRow = RowIndex 0
    , uiNotice = Nothing
    }

-- | The selected category, when one exists.
currentCategory :: AppState -> Maybe Category
currentCategory app =
  uiCategory (appUi app) >>= \identifier ->
    findCategory identifier (appWorkspace app)

-- | Tasks visible in the selected category and status column.
visibleTasks :: AppState -> [Task]
visibleTasks app =
  case uiCategory (appUi app) of
    Nothing -> []
    Just identifier ->
      tasksByStatus (uiStatus (appUi app))
        (categoryTasks identifier (appWorkspace app))

-- | Task under the cursor, or the task open on the details screen.
selectedTaskId :: AppState -> Maybe TaskId
selectedTaskId app =
  case uiScreen (appUi app) of
    DetailsScreen identifier -> Just identifier
    _ ->
      taskId <$> indexMaybe (rowIndexValue (uiRow (appUi app))) (visibleTasks app)

-- | Task under the cursor, when it still exists.
selectedTask :: AppState -> Maybe Task
selectedTask app =
  selectedTaskId app >>= \identifier ->
    findTask identifier (appWorkspace app)

-- | Replaces the current notice.
withNotice :: Notice -> AppState -> AppState
withNotice notice app =
  app { appUi = (appUi app) { uiNotice = Just notice } }
