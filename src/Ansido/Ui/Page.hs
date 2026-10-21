-- | Pure rendering of every screen into Ansiform pages.
module Ansido.Ui.Page
  ( renderPage
  , boardWindowSize
  , Window (..)
  , windowAround
  , taskTitlePrompt
  , taskTitlePromptColumn
  , taskContentPrompt
  , taskContentPromptColumn
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
      , sectionRule (rule '=' (themeRule (uiBase theme)))
      ]
    footer = footerSection theme (footerHints theme (uiScreen ui))
    promptSections =
      case uiScreen ui of
        AddTaskScreen     ->
          [ promptLine theme taskTitlePrompt
          , promptLine theme taskContentPrompt
          ]
        AddCategoryScreen -> [promptLine theme categoryPrompt]
        _                 -> []

-- | Body of the current screen, followed by an optional notice.
screenBody :: UiTheme -> AppState -> [Section]
screenBody theme app =
  body <> noticeSections theme app
  where
    body =
      case uiScreen (appUi app) of
        BoardScreen       -> boardBody theme app
        DetailsScreen _   -> detailsBody theme app
        HelpScreen        -> helpBody theme app
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
      [ emptySection theme
          "Create a category first, press Backspace to open categories." ]
  | null (visibleTasks app) =
      [ emptySection theme "No tasks yet, press Enter to add one." ]
  | otherwise =
      [ boardTableSection theme app ]

boardTableSection :: UiTheme -> AppState -> Section
boardTableSection theme app =
  sectionBody 1
    [ printerTableBordered BordersLight boardTableFormat 1 1
        (boardTable theme app) ]

-- | Title, note and state columns, with the note as the main field.
boardTableFormat :: TableFormat
boardTableFormat =
  tableFormat
    [ ColumnSpec AlignLeft (Just 20) (EllipsisChar '…')
    , ColumnSpec AlignLeft (Just 40) (EllipsisChar '…')
    , ColumnSpec AlignRight (Just 7) EllipsisNone
    ]

boardTable :: UiTheme -> AppState -> Maybe Table
boardTable theme app =
  tableBlocks
    [ blockSimple "Title" headerStyle
    , blockSimple "Note" headerStyle
    , blockSimple "State" headerStyle
    ]
    (aboveRows <> taskRows <> belowRows)
  where
    base = uiBase theme
    headerStyle = themeTableHeader base
    ui = appUi app
    tasks = visibleTasks app
    selected = selectedTaskId app
    win = windowAround boardWindowSize (rowIndexValue (uiRow ui)) tasks
    taskRows = map (taskRow theme selected) (windowItems win)
    aboveRows = if windowAbove win then [markerRow theme] else []
    belowRows = if windowBelow win then [markerRow theme] else []

taskRow :: UiTheme -> Maybe TaskId -> Task -> [Block]
taskRow theme selected task =
  [ blockSimple (marker <> taskTitleText (taskTitle task)) titleStyle
  , blockSimple noteText noteStyle
  , blockSimple (statusLabel (taskStatus task))
      (statusStyle theme (taskStatus task))
  ]
  where
    base = uiBase theme
    isSelected = Just (taskId task) == selected
    marker = if isSelected then "> " else "  "
    titleStyle = if isSelected then uiSelected theme else themeTableBody base
    noteText
      | null (taskContentText (taskContent task)) = "(empty)"
      | otherwise = taskContentText (taskContent task)
    noteStyle
      | isSelected = uiSelected theme
      | null (taskContentText (taskContent task)) = themeMuted base
      | otherwise = themeTableBody base

markerRow :: UiTheme -> [Block]
markerRow theme =
  [ blockSimple "..." (themeMuted (uiBase theme))
  , blockEmpty
  , blockEmpty
  ]

-- Details.
--------------------------------------------------------------------------------

detailsBody :: UiTheme -> AppState -> [Section]
detailsBody theme app =
  case selectedTask app of
    Nothing ->
      [ emptySection theme
          "No task selected. Press Backspace to return to the board." ]
    Just task ->
      [ sectionBody 1
          [ printerLeft 1 (fieldBlock theme "Title"
              (taskTitleText (taskTitle task))
              (uiSelected theme))
          , printerLeft 1 (fieldBlock theme "State"
              (statusLabel (taskStatus task))
              (statusStyle theme (taskStatus task)))
          , printerLeft 1 (fieldBlock theme "Category"
              (categoryNameFor (appWorkspace app) (taskCategory task))
              (themeTableBody base))
          , printerLeft 1 (blockSimple "Note:" (themeMuted base))
          , printerParagraph 3 0
              [ blockSimple (taskNoteText task) (taskNoteStyle theme task) ]
          ]
      ]
  where
    base = uiBase theme

taskNoteText :: Task -> String
taskNoteText task
  | null (taskContentText (taskContent task)) = "(empty)"
  | otherwise = taskContentText (taskContent task)

taskNoteStyle :: UiTheme -> Task -> Style
taskNoteStyle theme task
  | null (taskContentText (taskContent task)) = themeMuted (uiBase theme)
  | otherwise = themeTableBody (uiBase theme)

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

helpBody :: UiTheme -> AppState -> [Section]
helpBody theme app =
  [ titleSection theme "Help"
  , sectionBody 1
      [ printerTableBordered BordersLight defaultTableFormat 1 1
          (helpTable theme)
      , printerLeft 1 (blockSimple "Data file:" (themeMuted base))
      , printerParagraph 3 0
          [ blockSimple (dataFilePath app) (themeTableBody base) ]
      ]
  ]
  where
    base = uiBase theme

dataFilePath :: AppState -> String
dataFilePath app
  | null (appDataFile app) = "(not set)"
  | otherwise = appDataFile app

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
  [ ("↑ / ↓", "select a task")
  , ("j / k", "vim alternative")
  , ("Enter", "add a task")
  , ("Space", "cycle the selected task state")
  , ("d", "delete the selected task")
  , ("v", "view the full note")
  , ("Backspace / Esc", "go back one screen")
  , ("n", "create a category")
  , ("1 .. 9", "select a category")
  , ("r", "redraw the screen")
  , ("?", "open this help")
  , ("x", "exit")
  ]

-- Categories.
--------------------------------------------------------------------------------

categoriesBody :: UiTheme -> AppState -> [Section]
categoriesBody theme app =
  [ sectionBody 1
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
      | otherwise = themeMuted base
    countFor category =
      length (categoryTasks (categoryId category) workspace)

-- Footer.
--------------------------------------------------------------------------------

footerHints :: UiTheme -> Screen -> [Block]
footerHints theme screen =
  case screen of
    BoardScreen ->
      [ keyHintText theme "↑↓" "select"
      , keyHintText theme "Enter" "add"
      , keyHintText theme "Space" "state"
      , keyHint theme 'd' "del"
      , keyHint theme 'v' "view"
      , keyHintText theme "⌫" "back"
      , keyHint theme '?' "help"
      , keyHint theme 'x' "exit"
      ]
    DetailsScreen _ ->
      [ keyHintText theme "⌫" "back"
      , keyHintText theme "Space" "state"
      , keyHint theme 'd' "del"
      , keyHint theme 'x' "exit"
      ]
    HelpScreen ->
      [ keyHintText theme "⌫" "back"
      , keyHint theme 'x' "exit"
      ]
    CategoryScreen ->
      [ keyHint theme 'n' "new"
      , keyHintText theme "1-9" "select"
      , keyHintText theme "⌫" "back"
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
taskTitlePrompt :: String
taskTitlePrompt = "Task title: "

-- | Column where the task title input starts.
taskTitlePromptColumn :: Int
taskTitlePromptColumn = 2 + textWidth taskTitlePrompt

-- | Prompt printed for a new task note.
taskContentPrompt :: String
taskContentPrompt = "Task note:  "

-- | Column where the task note input starts.
taskContentPromptColumn :: Int
taskContentPromptColumn = 2 + textWidth taskContentPrompt

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

-- | Number of rows shown in the task table.
boardWindowSize :: Int
boardWindowSize = 10

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
