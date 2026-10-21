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
    let app = initialAppState workspace
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
  key <- readKey
  case key of
    Nothing -> pure ()
    Just char ->
      case commandForKey (uiScreen (appUi (loopApp state))) char of
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
    BackCommand -> applyAction path state OpenBoard
    HelpCommand -> applyAction path state OpenHelp
    CategoriesCommand -> applyAction path state OpenCategories
    DetailsCommand -> applyAction path state OpenDetails
    AddTaskCommand -> startTaskInput path state
    AddCategoryCommand -> startCategoryInput path state
    AdvanceCommand -> applyAction path state AdvanceSelected
    DeleteCommand -> applyAction path state DeleteSelected
    MoveColumnCommand direction ->
      applyAction path state (MoveColumn direction)
    MoveRowCommand direction ->
      applyAction path state (MoveRow direction)
    FocusStatusCommand status ->
      applyAction path state (FocusStatus status)
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

startTaskInput :: FilePath -> LoopState -> IO Step
startTaskInput path state =
  case update OpenAddTask (loopApp state) of
    Left domainError -> reportFailure state domainError
    Right app -> do
      drawing <- Draw.draw (renderPage defaultUiTheme app) (loopDraw state)
      input <- readLineAt 1 (formNumber taskPromptColumn)
      continueWithInput path app drawing SubmitTask input

startCategoryInput :: FilePath -> LoopState -> IO Step
startCategoryInput path state =
  case update OpenAddCategory (loopApp state) of
    Left domainError -> reportFailure state domainError
    Right app -> do
      drawing <- Draw.draw (renderPage defaultUiTheme app) (loopDraw state)
      input <- readLineAt 1 (formNumber categoryPromptColumn)
      continueWithInput path app drawing SubmitCategory input

continueWithInput :: FilePath -> AppState -> Draw.State
                 -> (String -> Action) -> Maybe String -> IO Step
continueWithInput path app drawing toAction input =
  case input of
    Nothing -> leaveInput app drawing
    Just value
      | all isSpace value -> leaveInput app drawing
      | otherwise -> applyAction path (LoopState app drawing) (toAction value)

leaveInput :: AppState -> Draw.State -> IO Step
leaveInput app drawing =
  case update OpenBoard app of
    Left domainError -> reportFailure (LoopState app drawing) domainError
    Right app' -> do
      drawing' <- Draw.draw (renderPage defaultUiTheme app') drawing
      pure (Continue (LoopState app' drawing'))

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
errorScreen screen = screen
