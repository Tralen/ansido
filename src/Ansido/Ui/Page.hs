-- | Pure rendering of every screen into Ansiform pages.
module Ansido.Ui.Page
  ( renderPage
  , renderTaskForm
  , renderCategoryForm
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

-- | A styled cell in a borderless table.
data Cell = Cell String Style

-- | Renders the current state as a page.
renderPage :: UiTheme -> AppState -> Page
renderPage theme app =
  page (pageChrome theme app <> promptSections theme app)

-- | Renders a task form and returns the prompts read by 'readForm'.
renderTaskForm :: UiTheme -> AppState -> (Page, [Prompt])
renderTaskForm theme app =
  ( page (before <> hintSections <> sections)
  , prompts
  )
  where
    before = pageChrome theme app
    editMode =
      case uiScreen (appUi app) of
        EditTaskScreen _ -> True
        _                -> False
    hintSections =
      if editMode
        then [ section [ printerLeft 2
                 (blockSimple "Empty input keeps the current value."
                    (themeMuted (uiBase theme))) ] ]
        else []
    titleIndex = length before + length hintSections
    contentIndex = titleIndex + 1
    sections =
      [ promptLine theme taskTitlePrompt
      , promptLine theme taskContentPrompt
      ]
    prompts =
      [ promptAt (formNumber titleIndex) 0
          (formNumber taskTitlePromptColumn)
      , promptAt (formNumber contentIndex) 0
          (formNumber taskContentPromptColumn)
      ]

-- | Renders a category form and returns the prompt read by 'readForm'.
renderCategoryForm :: UiTheme -> AppState -> (Page, [Prompt])
renderCategoryForm theme app =
  ( page (before <> hintSections <> sections)
  , prompts
  )
  where
    before = pageChrome theme app
    editMode =
      case uiScreen (appUi app) of
        EditCategoryScreen _ -> True
        _                    -> False
    hintSections =
      if editMode
        then [ section [ printerLeft 2
                 (blockSimple "Empty input keeps the current value."
                    (themeMuted (uiBase theme))) ] ]
        else []
    promptIndex = length before + length hintSections
    sections = [ promptLine theme categoryPrompt ]
    prompts =
      [ promptAt (formNumber promptIndex) 0
          (formNumber categoryPromptColumn)
      ]

pageChrome :: UiTheme -> AppState -> [Section]
pageChrome theme app =
  [ headerSection theme "ANSI DO!"
      ("Terminal task manager, v" <> versionText)
  , categorySection theme (uiCategory (appUi app))
      (workspaceCategories (appWorkspace app))
  , sectionRule (rule '=' (themeRule (uiBase theme)))
  ]
    <> screenBody theme app
    <> [ footerSection theme
          (footerHints theme (uiScreen (appUi app))) ]

promptSections :: UiTheme -> AppState -> [Section]
promptSections theme app =
  case uiScreen (appUi app) of
    AddTaskScreen     ->
      [ promptLine theme taskTitlePrompt
      , promptLine theme taskContentPrompt
      ]
    AddCategoryScreen -> [ promptLine theme categoryPrompt ]
    _                 -> []

-- | Body of the current screen, followed by an optional notice.
screenBody :: UiTheme -> AppState -> [Section]
screenBody theme app =
  case uiScreen (appUi app) of
    BoardScreen -> boardBody theme app
    AddTaskScreen -> boardBody theme app
    DetailsScreen _ -> detailsBody theme app <> noticeSections theme app
    EditTaskScreen _ -> detailsBody theme app <> noticeSections theme app
    HelpScreen -> helpBody theme app <> noticeSections theme app
    CategoryScreen -> categoriesBody theme app
    AddCategoryScreen -> categoriesBody theme app
    EditCategoryScreen _ ->
      categoryDetailsBody theme app <> noticeSections theme app

noticeSections :: UiTheme -> AppState -> [Section]
noticeSections theme app =
  case uiNotice (appUi app) of
    Nothing      -> []
    Just notice  -> [noticeSection theme notice]

noticePrinters :: UiTheme -> AppState -> [Printer]
noticePrinters theme app =
  case uiNotice (appUi app) of
    Nothing      -> []
    Just notice  -> [noticePrinter theme notice]

-- Board.
--------------------------------------------------------------------------------

boardBody :: UiTheme -> AppState -> [Section]
boardBody theme app
  | null (workspaceCategories (appWorkspace app)) =
      [ emptySection theme
          "Create a category first, press Backspace to open categories." ]
        <> noticeSections theme app
  | null (visibleTasks app) =
      [ boardEmptySection theme app (emptyMessage (uiFilter (appUi app))) ]
  | otherwise =
      [ boardTableSection theme app ]

emptyMessage :: Filter -> String
emptyMessage ShowAll = "No tasks yet, press Enter to add one."
emptyMessage (OnlyStatus status) = "No tasks in " <> statusLabel status <> "."

boardWidths :: [Int]
boardWidths = [20, 40, 7]

boardAligns :: [Align]
boardAligns = [AlignLeft, AlignLeft, AlignRight]

boardHeader :: UiTheme -> [Cell]
boardHeader theme =
  [ Cell "Title" (themeTableHeader base)
  , Cell "Note" (themeTableHeader base)
  , Cell "Status" (themeTableHeader base)
  ]
  where
    base = uiBase theme

boardTableSection :: UiTheme -> AppState -> Section
boardTableSection theme app =
  section
    ( [ filterPrinter theme app
      , printerEmpty 1
      , rowTablePrinter boardWidths boardAligns (boardHeader theme)
          (blankRow boardWidths (themeTableBody (uiBase theme))
            : boardRows theme app)
      ] <> noticePrinters theme app
        <> [ printerEmpty 1 ]
    )

boardEmptySection :: UiTheme -> AppState -> String -> Section
boardEmptySection theme app message =
  section
    ( [ filterPrinter theme app
      , printerEmpty 1
      , printerLeft 1 (blockSimple message (themeMuted base))
      ] <> noticePrinters theme app
        <> [ printerEmpty 1 ]
    )
  where
    base = uiBase theme

filterPrinter :: UiTheme -> AppState -> Printer
filterPrinter theme app =
  printerLeft 1 (blockCycle
    [ ("Filter: ", themeMuted (uiBase theme))
    , (filterLabel active, filterStyle active)
    ])
  where
    active = uiFilter (appUi app)
    filterStyle ShowAll = uiSelected theme
    filterStyle (OnlyStatus status) = statusStyle theme status

boardRows :: UiTheme -> AppState -> [[Cell]]
boardRows theme app =
  above <> map (taskCells theme selected) (windowItems win) <> below
  where
    ui = appUi app
    tasks = visibleTasks app
    selected = selectedTaskId app
    win = windowAround boardWindowSize (rowIndexValue (uiRow ui)) tasks
    above = if windowAbove win then [markerCells theme] else []
    below = if windowBelow win then [markerCells theme] else []

taskCells :: UiTheme -> Maybe TaskId -> Task -> [Cell]
taskCells theme selected task =
  [ Cell (marker <> taskTitleText (taskTitle task)) titleStyle
  , Cell noteText noteStyle
  , Cell (statusLabel (taskStatus task))
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

markerCells :: UiTheme -> [Cell]
markerCells theme =
  [ Cell "..." (themeMuted (uiBase theme))
  , Cell "" (themeTableBody (uiBase theme))
  , Cell "" (themeTableBody (uiBase theme))
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
          , printerLeft 1 (fieldBlock theme "Status"
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

helpWidths :: [Int]
helpWidths = [17, 32]

helpAligns :: [Align]
helpAligns = [AlignLeft, AlignLeft]

helpHeader :: UiTheme -> [Cell]
helpHeader theme =
  [ Cell "Key" (themeTableHeader (uiBase theme))
  , Cell "Action" (themeTableHeader (uiBase theme))
  ]

helpRows :: UiTheme -> [[Cell]]
helpRows theme =
  [ [ Cell key (uiSelected theme)
    , Cell description (themeTableBody (uiBase theme))
    ]
  | (key, description) <- helpEntries
  ]

helpBody :: UiTheme -> AppState -> [Section]
helpBody theme app =
  [ titleSection theme "Help"
  , sectionTop 1
      ( [ rowTablePrinter helpWidths helpAligns (helpHeader theme)
            (blankRow helpWidths (themeTableBody base) : helpRows theme)
        , printerEmpty 1
        , printerLeft 1
            (blockSimple "Data file:" (themeTableHeader base))
        , printerParagraph 3 0
            [ blockSimple (dataFilePath app) (themeTableBody base) ]
        ] )
  ]
  where
    base = uiBase theme

dataFilePath :: AppState -> String
dataFilePath app
  | null (appDataFile app) = "(not set)"
  | otherwise = appDataFile app

helpEntries :: [(String, String)]
helpEntries =
  [ ("↑ / ↓", "select a task or category")
  , ("j / k", "vim alternative")
  , ("w / s", "wasd alternative")
  , ("Enter", "add a task or open a category")
  , ("Space", "cycle the selected task status")
  , ("e", "edit the selected task or category")
  , ("f (board)", "filter by status")
  , ("Del", "delete the selected task or category")
  , ("v", "view the full note")
  , ("Backspace / Esc", "go back one screen")
  , ("n", "create a category")
  , ("1 .. 9", "open a category")
  , ("r", "redraw the screen")
  , ("?", "open this help")
  , ("x", "exit")
  ]

-- Categories.
--------------------------------------------------------------------------------

categoryWidths :: [Int]
categoryWidths = [3, 20, 6]

categoryAligns :: [Align]
categoryAligns = [AlignRight, AlignLeft, AlignRight]

categoryHeader :: UiTheme -> [Cell]
categoryHeader theme =
  [ Cell "#" (themeTableHeader base)
  , Cell "Category" (themeTableHeader base)
  , Cell "Tasks" (themeTableHeader base)
  ]
  where
    base = uiBase theme

categoryRows :: UiTheme -> AppState -> [[Cell]]
categoryRows theme app =
  [ [ Cell (show position) (uiSelected theme)
    , Cell (categoryNameText (categoryName category)) (nameStyle category)
    , Cell (show (countFor category)) (themeTableBody base)
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

categoriesBody :: UiTheme -> AppState -> [Section]
categoriesBody theme app =
  [ sectionBody 1
      (tablePrinter : (hintPrinters <> noticePrinters theme app)) ]
  where
    base = uiBase theme
    tablePrinter =
      rowTablePrinter categoryWidths categoryAligns
        (categoryHeader theme)
        (blankRow categoryWidths (themeTableBody base)
          : categoryRows theme app)
    hintPrinters =
      if null (workspaceCategories (appWorkspace app))
        then [ printerLeft 1
                 (blockSimple "Press n to create a category."
                    (themeMuted base)) ]
        else []

-- | Compact summary of the category that is being edited.
categoryDetailsBody :: UiTheme -> AppState -> [Section]
categoryDetailsBody theme app =
  case currentCategory app of
    Nothing ->
      [ emptySection theme
          "No category selected. Press Backspace to return to categories." ]
    Just category ->
      [ sectionBody 1
          [ printerLeft 1 (fieldBlock theme "Name"
              (categoryNameText (categoryName category))
              (uiSelected theme))
          , printerLeft 1 (fieldBlock theme "Tasks"
              (show (length (categoryTasks (categoryId category)
                                          (appWorkspace app))))
              (themeTableBody base))
          ]
      ]
  where
    base = uiBase theme

-- Footer.
--------------------------------------------------------------------------------

footerHints :: UiTheme -> Screen -> [Block]
footerHints theme screen =
  case screen of
    BoardScreen ->
      [ blockSimple "↑↓" (uiSelected theme)
      , keyHintText theme "Enter" "add"
      , keyHintText theme "Space" "status"
      , keyHint theme 'e' "edit"
      , keyHint theme 'f' "filter"
      , keyHintText theme "Del" "del"
      , keyHintText theme "?" "help"
      , keyHintText theme "⌫" "back"
      , keyHint theme 'x' "exit"
      ]
    DetailsScreen _ ->
      [ keyHintText theme "⌫" "back"
      , keyHintText theme "Space" "status"
      , keyHint theme 'e' "edit"
      , keyHintText theme "Del" "del"
      , keyHint theme 'x' "exit"
      ]
    EditTaskScreen _ ->
      [ keyHintText theme "Enter" "confirm" ]
    EditCategoryScreen _ ->
      [ keyHintText theme "Enter" "confirm" ]
    HelpScreen ->
      [ keyHintText theme "⌫" "back"
      , keyHint theme 'x' "exit"
      ]
    CategoryScreen ->
      [ blockSimple "↑↓" (uiSelected theme)
      , keyHintText theme "Enter" "open"
      , keyHint theme 'n' "new"
      , keyHint theme 'e' "edit"
      , keyHintText theme "Del" "del"
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

-- Table rendering.
--------------------------------------------------------------------------------

-- | Builds a table printer that keeps the fixed widths and styles of the cells.
rowTablePrinter :: [Int] -> [Align] -> [Cell] -> [[Cell]] -> Printer
rowTablePrinter widths aligns header rows =
  printerTableBordered BordersNone defaultTableFormat 1 0
    (tableBlocks
      (zipWith3 cellBlock widths aligns header)
      [ zipWith3 cellBlock widths aligns row | row <- rows ])

-- | Pads one cell to its column width and keeps its style.
cellBlock :: Int -> Align -> Cell -> Block
cellBlock columnWidth align (Cell text style) =
  blockSimple (padCell columnWidth align text) style

-- | A blank row used to separate the header from the body.
blankRow :: [Int] -> Style -> [Cell]
blankRow widths style = replicate (length widths) (Cell "" style)

padCell :: Int -> Align -> String -> String
padCell columnWidth align text =
  let clipped = truncateVisible columnWidth text
      gap = max 0 (columnWidth - textWidth clipped)
  in case align of
       AlignLeft -> clipped <> replicate gap ' '
       AlignRight -> replicate gap ' ' <> clipped
       AlignCenter ->
         replicate (gap `div` 2) ' '
           <> clipped
           <> replicate (gap - gap `div` 2) ' '

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
