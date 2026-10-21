-- | Pure rendering of every screen into Ansiform pages.
module Ansido.Ui.Page
  ( renderPage
  , boardWindowSize
  , Window (..)
  , windowAround
  , taskPrompt
  , taskPromptColumn
  , categoryPrompt
  , categoryPromptColumn
  ) where

--------------------------------------------------------------------------------
import           Ansiform hiding (renderPage)

import           Ansido.App.State
import           Ansido.Domain
import           Ansido.Ui.Components
import           Ansido.Ui.Theme
import           Ansido.Version (versionText)

-- | Renders the current state as a page.
renderPage :: UiTheme -> AppState -> Page
renderPage theme app =
  page (headerSections <> screenBody theme app <> [footer] <> promptSections)
  where
    ui = appUi app
    headerSections =
      [ headerSection theme "ANSI DO!"
          ("Terminal task manager, v" <> versionText)
      , categorySection theme (uiCategory ui)
          (workspaceCategories (appWorkspace app))
      ]
    footer = footerSection theme (footerHints theme (uiScreen ui))
    promptSections =
      case uiScreen ui of
        AddTaskScreen     -> [promptLine theme taskPrompt]
        AddCategoryScreen -> [promptLine theme categoryPrompt]
        _                 -> []

-- | Body of the current screen, preceded by an optional notice.
screenBody :: UiTheme -> AppState -> [Section]
screenBody theme app =
  noticeSections theme app
    <> case uiScreen (appUi app) of
         BoardScreen       -> boardBody theme app
         DetailsScreen _   -> detailsBody theme app
         HelpScreen        -> helpBody theme
         CategoryScreen    -> categoriesBody theme app
         AddTaskScreen     -> boardBody theme app
         AddCategoryScreen -> categoriesBody theme app

noticeSections :: UiTheme -> AppState -> [Section]
noticeSections theme app =
  case uiNotice (appUi app) of
    Nothing      -> []
    Just notice  -> [noticeSection theme notice]

-- Board.
--------------------------------------------------------------------------------

boardBody :: UiTheme -> AppState -> [Section]
boardBody theme app
  | null (workspaceCategories (appWorkspace app)) =
      [ emptySection theme "Create a category with c to get started." ]
  | otherwise = [ boardSection theme app ]

boardSection :: UiTheme -> AppState -> Section
boardSection theme app =
  sectionBody 1
    [ printerGroupsBordered BordersLight 1 1 (boardColumns theme app) ]

boardColumns :: UiTheme -> AppState -> [Group]
boardColumns theme app =
  [ groupSimple (statusBlock theme status (length tasks)) body
  | ((status, tasks), body) <- zip columns paddedBodies
  ]
  where
    ui = appUi app
    selected = selectedTaskId app
    columns =
      [ (status, tasksFor status) | status <- allStatuses ]
    tasksFor status =
      case uiCategory ui of
        Nothing -> []
        Just identifier ->
          tasksByStatus status (categoryTasks identifier (appWorkspace app))
    bodies =
      [ statusColumnBody theme ui selected status tasks
      | (status, tasks) <- columns
      ]
    highest = maximum (0 : map length bodies)
    paddedBodies = map (padBody highest) bodies

statusColumnBody :: UiTheme -> UiState -> Maybe TaskId -> Status -> [Task] -> [Block]
statusColumnBody theme ui selected status tasks
  | null tasks = [mutedBlock theme "  (empty)"]
  | otherwise =
      above <> map (taskLine theme selectedHere) (windowItems win) <> below
  where
    current = status == uiStatus ui
    position = if current then rowIndexValue (uiRow ui) else 0
    win = windowAround boardWindowSize position tasks
    selectedHere = if current then selected else Nothing
    above = if windowAbove win then [mutedBlock theme "  ..."] else []
    below = if windowBelow win then [mutedBlock theme "  ..."] else []

padBody :: Int -> [Block] -> [Block]
padBody target body =
  body <> replicate (max 0 (target - length body)) blockEmpty

taskLine :: UiTheme -> Maybe TaskId -> Task -> Block
taskLine theme selected task =
  blockCycle
    [ (marker, markerStyle)
    , (truncateVisible taskTitleWidth (taskTitleText (taskTitle task)), titleStyle)
    ]
  where
    isSelected = Just (taskId task) == selected
    marker = if isSelected then "> " else "  "
    markerStyle = if isSelected then uiSelected theme else themeMuted base
    titleStyle = if isSelected then uiSelected theme else themeTableBody base
    base = uiBase theme

taskTitleWidth :: Int
taskTitleWidth = 20

-- Details.
--------------------------------------------------------------------------------

detailsBody :: UiTheme -> AppState -> [Section]
detailsBody theme app =
  case selectedTask app of
    Nothing ->
      [ emptySection theme "No task selected. Press b to return to the board." ]
    Just task ->
      [ titleSection theme "Task details"
      , sectionBody 1
          [ printerLeft 1 (fieldBlock theme "Id"
              (show (taskIdValue (taskId task)))
              (themeTableBody base))
          , printerLeft 1 (fieldBlock theme "Title"
              (taskTitleText (taskTitle task))
              (uiSelected theme))
          , printerLeft 1 (fieldBlock theme "Status"
              (statusLabel (taskStatus task))
              (statusStyle theme (taskStatus task)))
          , printerLeft 1 (fieldBlock theme "Category"
              (categoryNameFor (appWorkspace app) (taskCategory task))
              (themeAccent base))
          ]
      ]
  where
    base = uiBase theme

fieldBlock :: UiTheme -> String -> String -> Style -> Block
fieldBlock theme label value style =
  blockCycle
    [ (label, themeMuted (uiBase theme))
    , (": ", themeMuted (uiBase theme))
    , (value, style)
    ]

categoryNameFor :: Workspace -> CategoryId -> String
categoryNameFor workspace identifier =
  case findCategory identifier workspace of
    Just category -> categoryNameText (categoryName category)
    Nothing       -> "(unknown)"

-- Help.
--------------------------------------------------------------------------------

helpBody :: UiTheme -> [Section]
helpBody theme =
  [ titleSection theme "Help"
  , sectionBody 1
      [ printerTableBordered BordersLight defaultTableFormat 1 1
          (helpTable theme) ]
  ]

helpTable :: UiTheme -> Maybe Table
helpTable theme =
  tableBlocks
    [ blockSimple "Key" (themeTableHeader (uiBase theme))
    , blockSimple "Action" (themeTableHeader (uiBase theme))
    ]
    [ [ blockSimple key (uiSelected theme)
      , blockSimple description (themeTableBody (uiBase theme))
      ]
    | (key, description) <- helpEntries
    ]

helpEntries :: [(String, String)]
helpEntries =
  [ ("h / l", "move between columns")
  , ("j / k", "move inside a column")
  , ("1 / 2 / 3", "focus a column")
  , ("a", "add a task")
  , ("m", "advance the selected task")
  , ("d", "delete the selected task")
  , ("v", "open task details")
  , ("c", "open categories")
  , ("n", "create a category")
  , ("1 .. 9", "select a category")
  , ("b / Esc", "go back")
  , ("r", "redraw the screen")
  , ("?", "open this help")
  , ("x", "exit")
  ]

-- Categories.
--------------------------------------------------------------------------------

categoriesBody :: UiTheme -> AppState -> [Section]
categoriesBody theme app =
  [ titleSection theme "Categories"
  , sectionBody 1
      [ printerTableBordered BordersLight defaultTableFormat 1 1
          (categoryTable theme app)
      , printerLeft 1
          (blockSimple "Press n to create a category." (themeMuted base))
      ]
  ]
  where
    base = uiBase theme

categoryTable :: UiTheme -> AppState -> Maybe Table
categoryTable theme app =
  tableBlocks
    [ blockSimple "#" (themeTableHeader base)
    , blockSimple "Category" (themeTableHeader base)
    , blockSimple "Tasks" (themeTableHeader base)
    ]
    [ [ blockSimple (show position) (uiSelected theme)
      , blockSimple (categoryNameText (categoryName category)) (nameStyle category)
      , blockSimple (show (countFor category)) (themeTableBody base)
      ]
    | (position, category) <- indexedCategories
    ]
  where
    base = uiBase theme
    workspace = appWorkspace app
    active = uiCategory (appUi app)
    categories = workspaceCategories workspace
    indexedCategories = zip [1 .. length categories] categories
    nameStyle category
      | Just (categoryId category) == active = uiSelected theme
      | otherwise = themeTableBody base
    countFor category =
      length (categoryTasks (categoryId category) workspace)

-- Footer.
--------------------------------------------------------------------------------

footerHints :: UiTheme -> Screen -> [Block]
footerHints theme screen =
  case screen of
    BoardScreen ->
      [ keyHint theme 'a' "add"
      , keyHint theme 'm' "move"
      , keyHint theme 'd' "del"
      , keyHint theme 'v' "view"
      , keyHint theme 'c' "cats"
      , keyHint theme '?' "help"
      , keyHint theme 'x' "exit"
      ]
    DetailsScreen _ ->
      [ keyHint theme 'b' "back"
      , keyHint theme 'm' "move"
      , keyHint theme 'd' "del"
      , keyHint theme 'x' "exit"
      ]
    HelpScreen ->
      [ keyHint theme 'b' "back"
      , keyHint theme 'x' "exit"
      ]
    CategoryScreen ->
      [ keyHint theme 'n' "new"
      , keyHintText theme "1-9" "select"
      , keyHint theme 'b' "back"
      , keyHint theme 'x' "exit"
      ]
    AddTaskScreen ->
      [ keyHintText theme "Enter" "confirm"
      , keyHintText theme "empty" "cancel"
      ]
    AddCategoryScreen ->
      [ keyHintText theme "Enter" "confirm"
      , keyHintText theme "empty" "cancel"
      ]

-- Prompt.
--------------------------------------------------------------------------------

-- | Prompt printed for a new task title.
taskPrompt :: String
taskPrompt = "Task title: "

-- | Column where the task title input starts.
taskPromptColumn :: Int
taskPromptColumn = 2 + textWidth taskPrompt

-- | Prompt printed for a new category name.
categoryPrompt :: String
categoryPrompt = "Category name: "

-- | Column where the category name input starts.
categoryPromptColumn :: Int
categoryPromptColumn = 2 + textWidth categoryPrompt

promptLine :: UiTheme -> String -> Section
promptLine theme label =
  section [ printerLeft 2 (blockSimple label (uiSelected theme)) ]

-- Utilities.
--------------------------------------------------------------------------------

mutedBlock :: UiTheme -> String -> Block
mutedBlock theme text =
  blockSimple text (themeMuted (uiBase theme))

-- | Number of rows shown per board column.
boardWindowSize :: Int
boardWindowSize = 8

-- | A slice of a list with flags telling whether entries were hidden.
data Window a = Window
  { windowAbove :: Bool
  , windowItems :: [a]
  , windowBelow :: Bool
  } deriving (Eq, Show)

-- | Takes a slice of a fixed size that keeps the selected index visible.
windowAround :: Int -> Int -> [a] -> Window a
windowAround size index items =
  Window
    { windowAbove = offset > 0
    , windowItems = take size (drop offset items)
    , windowBelow = offset + size < total
    }
  where
    total = length items
    offset
      | total <= size = 0
      | otherwise = max 0 (min (total - size) (index - size `div` 2))
