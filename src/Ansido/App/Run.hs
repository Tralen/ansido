-- | IO edge: input, drawing and persistence.
--
-- The loop reads keys, turns them into commands and delegates every state
-- change to the pure update. Workspace changes are saved immediately.
module Ansido.App.Run
  ( runApp
  , runAppWith
  ) where

--------------------------------------------------------------------------------
import           Data.Char (isSpace)
import           System.Exit (exitFailure)
import           System.IO (hPutStrLn, stderr)
import           System.Timeout (timeout)

import           Ansiform hiding (State, renderPage)
import qualified Ansiform.Draw as Draw

import           Ansido.App.Command
import           Ansido.App.State
import           Ansido.App.Update
import           Ansido.Domain
import           Ansido.Persistence
import           Ansido.Ui.Components (Notice (..), NoticeKind (..))
import           Ansido.Ui.Page
import           Ansido.Ui.Theme

-- | Loads the default data file and starts the interface.
runApp :: IO ()
runApp = do
  fileResult <- defaultDataFile
  case fileResult of
    Left persistenceError ->
      failStartup persistenceError
    Right path -> do
      workspaceResult <- loadWorkspace path
      case workspaceResult of
        Left persistenceError ->
          failStartup persistenceError
        Right workspace -> runAppWith path workspace

failStartup :: PersistenceError -> IO a
failStartup persistenceError = do
  hPutStrLn stderr (persistenceErrorMessage persistenceError)
  exitFailure

-- | Starts the interface with an already loaded workspace.
runAppWith :: FilePath -> Workspace -> IO ()
runAppWith path workspace =
  withImmediateInput $ do
    let app = withDataFile path (initialAppState workspace)
    drawing <- Draw.start (renderPage defaultUiTheme app) defaultSettings
    loop path (LoopState app drawing)

-- Loop.
--------------------------------------------------------------------------------

data LoopState = LoopState
  { loopApp    :: AppState
  , loopDraw   :: Draw.State
  }

data Step
  = Continue LoopState
  | Stop

loop :: FilePath -> LoopState -> IO ()
loop path state = do
  key <- readKeyEvent
  case key of
    Nothing -> pure ()
    Just event ->
      case commandForKey (uiScreen (appUi (loopApp state))) event of
        Nothing -> loop path state
        Just command -> do
          step <- execute path state command
          case step of
            Stop          -> pure ()
            Continue next -> loop path next

execute :: FilePath -> LoopState -> Command -> IO Step
execute path state command =
  case command of
    QuitCommand -> pure Stop
    RedrawCommand -> do
      drawing <- Draw.redraw (loopDraw state)
      pure (Continue state { loopDraw = drawing })
    BackCommand ->
      applyAction path state
        (backAction (uiScreen (appUi (loopApp state))))
    HelpCommand -> applyAction path state OpenHelp
    CategoriesCommand -> applyAction path state OpenCategories
    DetailsCommand -> applyAction path state OpenDetails
    EditTaskCommand -> startEditTaskInput path state
    AddTaskCommand -> startTaskInput path state
    AddCategoryCommand -> startCategoryInput path state
    CycleFilterCommand -> applyAction path state CycleFilter
    CycleCommand -> applyAction path state CycleSelected
    DeleteCommand -> applyAction path state DeleteSelected
    MoveRowCommand direction ->
      applyAction path state (MoveRow direction)
    SelectCategoryCommand position ->
      selectCategoryByPosition path state position

-- Actions.
--------------------------------------------------------------------------------

applyAction :: FilePath -> LoopState -> Action -> IO Step
applyAction path state action =
  case update action (loopApp state) of
    Left domainError -> do
      let base = loopApp state
          app = withNotice
            (Notice NoticeError (domainErrorMessage domainError))
            (base { appUi = (appUi base)
              { uiScreen = errorScreen (uiScreen (appUi base)) } })
      drawing <- Draw.draw (renderPage defaultUiTheme app) (loopDraw state)
      pure (Continue (LoopState app drawing))
    Right app -> do
      let previous = appWorkspace (loopApp state)
          current = appWorkspace app
          changed = current /= previous
      saved <- if changed
        then saveWorkspace path current
        else pure (Right ())
      case saved of
        Right () -> do
          drawing <- Draw.draw (renderPage defaultUiTheme app) (loopDraw state)
          pure (Continue (LoopState app drawing))
        Left persistenceError -> do
          let app' = withNotice
                (Notice NoticeError (persistenceErrorMessage persistenceError))
                app
          drawing <- Draw.draw (renderPage defaultUiTheme app') (loopDraw state)
          pure (Continue (LoopState app' drawing))

selectCategoryByPosition :: FilePath -> LoopState -> Int -> IO Step
selectCategoryByPosition path state position =
  case drop (max 0 (position - 1))
       (workspaceCategories (appWorkspace (loopApp state))) of
    (category : _) ->
      applyAction path state (SelectCategory (categoryId category))
    [] ->
      applyAction path state
        (SetNotice (Notice NoticeInfo "No category with that number."))

-- Text input.
--------------------------------------------------------------------------------

startEditTaskInput :: FilePath -> LoopState -> IO Step
startEditTaskInput path state =
  case update OpenEditTask (loopApp state) of
    Left domainError -> reportFailure state domainError
    Right app ->
      case uiScreen (appUi app) of
        EditTaskScreen identifier -> do
          let (formPage, prompts) = renderTaskForm defaultUiTheme app
          (drawing, result) <- readForm formPage prompts (loopDraw state)
          case result of
            Left _ -> leaveInput app drawing
            Right [rawTitle, rawContent] ->
              applyAction path (LoopState app drawing)
                (SubmitEdit identifier rawTitle rawContent)
            Right _ -> leaveInput app drawing
        _ -> do
          drawing <- Draw.draw (renderPage defaultUiTheme app) (loopDraw state)
          pure (Continue (LoopState app drawing))

startTaskInput :: FilePath -> LoopState -> IO Step
startTaskInput path state =
  case update OpenAddTask (loopApp state) of
    Left domainError -> reportFailure state domainError
    Right app ->
      case uiScreen (appUi app) of
        AddTaskScreen -> do
          let (formPage, prompts) = renderTaskForm defaultUiTheme app
          (drawing, result) <- readForm formPage prompts (loopDraw state)
          case result of
            Left _ -> leaveInput app drawing
            Right [rawTitle, rawContent]
              | all isSpace rawTitle -> leaveInput app drawing
              | otherwise ->
                  applyAction path (LoopState app drawing)
                    (SubmitTask rawTitle rawContent)
            Right _ -> leaveInput app drawing
        _ -> do
          drawing <- Draw.draw (renderPage defaultUiTheme app) (loopDraw state)
          pure (Continue (LoopState app drawing))

startCategoryInput :: FilePath -> LoopState -> IO Step
startCategoryInput path state =
  case update OpenAddCategory (loopApp state) of
    Left domainError -> reportFailure state domainError
    Right app -> do
      let (formPage, prompts) = renderCategoryForm defaultUiTheme app
      (drawing, result) <- readForm formPage prompts (loopDraw state)
      case result of
        Left _ -> leaveInput app drawing
        Right [rawName]
          | all isSpace rawName -> leaveInput app drawing
          | otherwise ->
              applyAction path (LoopState app drawing)
                (SubmitCategory rawName)
        Right _ -> leaveInput app drawing

leaveInput :: AppState -> Draw.State -> IO Step
leaveInput app drawing =
  case update (cancelAction (uiScreen (appUi app))) app of
    Left domainError -> reportFailure (LoopState app drawing) domainError
    Right app' -> do
      drawing' <- Draw.draw (renderPage defaultUiTheme app') drawing
      pure (Continue (LoopState app' drawing'))

cancelAction :: Screen -> Action
cancelAction AddCategoryScreen = OpenCategories
cancelAction _ = OpenBoard

reportFailure :: LoopState -> DomainError -> IO Step
reportFailure state domainError = do
  let base = loopApp state
      app = withNotice
        (Notice NoticeError (domainErrorMessage domainError))
        (base { appUi = (appUi base)
          { uiScreen = errorScreen (uiScreen (appUi base)) } })
  drawing <- Draw.draw (renderPage defaultUiTheme app) (loopDraw state)
  pure (Continue (LoopState app drawing))

errorScreen :: Screen -> Screen
errorScreen AddTaskScreen = BoardScreen
errorScreen AddCategoryScreen = CategoryScreen
errorScreen (EditTaskScreen _) = BoardScreen
errorScreen screen = screen

escapeDelay :: Int
escapeDelay = 30000

-- | Reads a key and decodes ANSI arrow sequences into 'Key' values.
readKeyEvent :: IO (Maybe Key)
readKeyEvent = do
  key <- readKey
  case key of
    Nothing -> pure Nothing
    Just '\r' -> pure (Just KeyEnter)
    Just '\n' -> pure (Just KeyEnter)
    Just '\DEL' -> pure (Just KeyBackspace)
    Just '\b' -> pure (Just KeyBackspace)
    Just '\ESC' -> readEscape
    Just char -> pure (Just (KeyCharacter char))

readEscape :: IO (Maybe Key)
readEscape = do
  next <- timeout escapeDelay readKey
  case next of
    Nothing -> pure (Just KeyEscape)
    Just Nothing -> pure Nothing
    Just (Just '[') -> readArrow
    Just (Just 'O') -> readArrow
    Just (Just _) -> pure (Just KeyEscape)

readArrow :: IO (Maybe Key)
readArrow = do
  next <- timeout escapeDelay readKey
  case next of
    Just (Just 'A') -> pure (Just KeyUp)
    Just (Just 'B') -> pure (Just KeyDown)
    Just (Just 'C') -> pure (Just KeyRight)
    Just (Just 'D') -> pure (Just KeyLeft)
    Just (Just '3') -> readDeleteTail
    Just Nothing    -> pure Nothing
    _               -> pure (Just KeyEscape)

readDeleteTail :: IO (Maybe Key)
readDeleteTail = do
  next <- timeout escapeDelay readKey
  case next of
    Just (Just '~') -> pure (Just KeyDelete)
    Just Nothing    -> pure Nothing
    _               -> pure (Just KeyEscape)
