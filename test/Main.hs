-- | Pure tests for the domain, persistence and update rules.
module Main (main) where

--------------------------------------------------------------------------------
import           System.Exit (exitFailure)

import           Ansiform (formNumber, promptColumn, promptRow, promptSection)

import           Ansido.App.Command (Command (..), Key (..), commandForKey)
import           Ansido.App.State
import           Ansido.App.Update (backAction, update)
import           Ansido.Domain
import           Ansido.Persistence
import           Ansido.Ui.Components (Notice (..), NoticeKind (..),
                                       truncateVisible)
import           Ansido.Ui.Page (Window (..), renderTaskForm,
                                 taskContentPromptColumn, taskTitlePromptColumn,
                                 windowAround)
import           Ansido.Ui.Theme (defaultUiTheme)

-- Harness.
--------------------------------------------------------------------------------

type Check = Either String ()

check :: String -> Bool -> Check
check label condition =
  if condition then Right () else Left label

checkEqual :: (Eq a, Show a) => String -> a -> a -> Check
checkEqual label expected actual
  | expected == actual = Right ()
  | otherwise = Left
      (label <> ": expected " <> show expected <> ", got " <> show actual)

rightOr :: Show e => Either e a -> Either String a
rightOr result =
  case result of
    Left err    -> Left (show err)
    Right value -> Right value

isLeft :: Either a b -> Bool
isLeft result =
  case result of
    Left _  -> True
    Right _ -> False

-- Fixtures.
--------------------------------------------------------------------------------

buildFixture :: Either String (Category, Workspace)
buildFixture = do
  name <- rightOr (mkCategoryName "Work")
  addedCategory <- rightOr (addCategory name emptyWorkspace)
  let category = fst addedCategory
      workspace1 = snd addedCategory
  titleA <- rightOr (mkTaskTitle "Write docs")
  contentA <- rightOr (mkTaskContent "First note")
  addedA <- rightOr (addTask (categoryId category) titleA contentA workspace1)
  titleB <- rightOr (mkTaskTitle "Ship release")
  contentB <- rightOr (mkTaskContent "")
  addedB <- rightOr (addTask (categoryId category) titleB contentB (snd addedA))
  pure (category, snd addedB)

fixtureWorkspace :: Either String Workspace
fixtureWorkspace = snd <$> buildFixture

fixtureCategory :: Either String Category
fixtureCategory = fst <$> buildFixture

-- Tests.
--------------------------------------------------------------------------------

tests :: [(String, Check)]
tests =
  [ testTaskTitleValidation
  , testTaskContentValidation
  , testCategoryNameValidation
  , testAddTask
  , testAddTaskUnknownCategory
  , testMoveTask
  , testAdvanceTaskCycle
  , testDeleteTask
  , testDuplicateCategory
  , testWorkspaceInvariants
  , testEncodeDecode
  , testDecodeEmpty
  , testDecodeBadHeader
  , testDecodeBadStatus
  , testDecodeVersion1
  , testWindowStart
  , testWindowMiddle
  , testWindowEnd
  , testTruncate
  , testInitialState
  , testCycleStatus
  , testFilter
  , testEditTask
  , testEditBlankKeeps
  , testMoveRow
  , testSubmitTask
  , testSubmitCategory
  , testSelectUnknownCategory
  , testAddTaskWithoutCategory
  , testOpenDetails
  , testTaskFormPrompts
  , testArrowKeys
  , testDeleteKey
  , testWsKeys
  , testBackActions
  ]

testTaskTitleValidation :: (String, Check)
testTaskTitleValidation =
  ( "task title validation"
  , do
      check "empty title accepted" (isLeft (mkTaskTitle ""))
      check "blank title accepted" (isLeft (mkTaskTitle "   "))
      check "control character accepted" (isLeft (mkTaskTitle "a\tb"))
      title <- rightOr (mkTaskTitle "  Write docs  ")
      checkEqual "title is trimmed" "Write docs" (taskTitleText title)
  )

testTaskContentValidation :: (String, Check)
testTaskContentValidation =
  ( "task content validation"
  , do
      emptyContent <- rightOr (mkTaskContent "")
      checkEqual "empty content allowed" "" (taskContentText emptyContent)
      content <- rightOr (mkTaskContent "  Some note  ")
      checkEqual "content is trimmed" "Some note" (taskContentText content)
      check "control character accepted" (isLeft (mkTaskContent "a\tb"))
      check "long content accepted"
        (isLeft (mkTaskContent (replicate 501 'x')))
  )

testCategoryNameValidation :: (String, Check)
testCategoryNameValidation =
  ( "category name validation"
  , do
      check "empty name accepted" (isLeft (mkCategoryName ""))
      name <- rightOr (mkCategoryName " Work ")
      checkEqual "name is trimmed" "Work" (categoryNameText name)
  )

testAddTask :: (String, Check)
testAddTask =
  ( "add task"
  , do
      fixture <- buildFixture
      let category = fst fixture
          workspace = snd fixture
      title <- rightOr (mkTaskTitle "Review")
      content <- rightOr (mkTaskContent "Review note")
      added <- rightOr (addTask (categoryId category) title content workspace)
      let task = fst added
          updated = snd added
      checkEqual "task id" 3 (taskIdValue (taskId task))
      checkEqual "task status" Todo (taskStatus task)
      checkEqual "task content" "Review note" (taskContentText (taskContent task))
      checkEqual "task count" 3 (length (workspaceTasks updated))
  )

testAddTaskUnknownCategory :: (String, Check)
testAddTaskUnknownCategory =
  ( "add task to unknown category"
  , do
      workspace <- fixtureWorkspace
      title <- rightOr (mkTaskTitle "Review")
      content <- rightOr (mkTaskContent "Note")
      check "unknown category accepted"
        (isLeft (addTask (CategoryId 99) title content workspace))
  )

testMoveTask :: (String, Check)
testMoveTask =
  ( "move task"
  , do
      workspace <- fixtureWorkspace
      updated <- rightOr (moveTask (TaskId 1) Doing workspace)
      checkEqual "first task moved" (Just Doing) (taskStatus <$> findTask (TaskId 1) updated)
      checkEqual "second task untouched" (Just Todo) (taskStatus <$> findTask (TaskId 2) updated)
  )

testAdvanceTaskCycle :: (String, Check)
testAdvanceTaskCycle =
  ( "advance task cycle"
  , do
      workspace <- fixtureWorkspace
      once <- rightOr (advanceTask (TaskId 1) workspace)
      twice <- rightOr (advanceTask (TaskId 1) once)
      thrice <- rightOr (advanceTask (TaskId 1) twice)
      checkEqual "todo to doing" (Just Doing) (taskStatus <$> findTask (TaskId 1) once)
      checkEqual "doing to done" (Just Done) (taskStatus <$> findTask (TaskId 1) twice)
      checkEqual "done to todo" (Just Todo) (taskStatus <$> findTask (TaskId 1) thrice)
  )

testDeleteTask :: (String, Check)
testDeleteTask =
  ( "delete task"
  , do
      workspace <- fixtureWorkspace
      updated <- rightOr (deleteTask (TaskId 1) workspace)
      checkEqual "task removed" Nothing (findTask (TaskId 1) updated)
      checkEqual "other task kept" (Just (TaskId 2)) (taskId <$> findTask (TaskId 2) updated)
  )

testDuplicateCategory :: (String, Check)
testDuplicateCategory =
  ( "duplicate category"
  , do
      name <- rightOr (mkCategoryName "Work")
      added <- rightOr (addCategory name emptyWorkspace)
      check "duplicate accepted" (isLeft (addCategory name (snd added)))
  )

testWorkspaceInvariants :: (String, Check)
testWorkspaceInvariants =
  ( "workspace invariants"
  , do
      category <- fixtureCategory
      workspace <- fixtureWorkspace
      let categoryDuplicate = Category (categoryId category) (categoryName category)
          task = Task (TaskId 1) (TaskTitle "x") (TaskContent "") Todo
                     (CategoryId 99)
      check "duplicate category id accepted"
        (isLeft (mkWorkspace [category, categoryDuplicate] (workspaceTasks workspace)))
      check "unknown category accepted"
        (isLeft (mkWorkspace [category] [task]))
  )

testEncodeDecode :: (String, Check)
testEncodeDecode =
  ( "encode and decode"
  , do
      workspace <- fixtureWorkspace
      checkEqual "roundtrip" (Right workspace) (decodeWorkspace (encodeWorkspace workspace))
  )

testDecodeEmpty :: (String, Check)
testDecodeEmpty =
  ( "decode empty file"
  , checkEqual "empty file" (Right emptyWorkspace) (decodeWorkspace "")
  )

testDecodeBadHeader :: (String, Check)
testDecodeBadHeader =
  ( "decode bad header"
  , check "bad header accepted" (isLeft (decodeWorkspace "other\t1\n"))
  )

testDecodeBadStatus :: (String, Check)
testDecodeBadStatus =
  ( "decode bad status"
  , check "bad status accepted"
      (isLeft (decodeWorkspace "ansido\t1\ntask\t1\t1\tlater\tTitle\n"))
  )

testDecodeVersion1 :: (String, Check)
testDecodeVersion1 =
  ( "decode version 1"
  , case decodeWorkspace
      "ansido\t1\ncategory\t1\tWork\ntask\t1\t1\ttodo\tLegacy\n" of
      Left err -> Left (show err)
      Right workspace ->
        case findTask (TaskId 1) workspace of
          Nothing -> Left "task missing"
          Just task ->
            checkEqual "legacy content" ""
              (taskContentText (taskContent task))
  )

testWindowStart :: (String, Check)
testWindowStart =
  ( "window at start"
  , let win = windowAround 3 0 [1 .. 10 :: Int]
    in do
      checkEqual "above" False (windowAbove win)
      checkEqual "items" [1, 2, 3] (windowItems win)
      checkEqual "below" True (windowBelow win)
  )

testWindowMiddle :: (String, Check)
testWindowMiddle =
  ( "window in the middle"
  , let win = windowAround 3 5 [1 .. 10 :: Int]
    in do
      checkEqual "above" True (windowAbove win)
      checkEqual "items" [5, 6, 7] (windowItems win)
      checkEqual "below" True (windowBelow win)
  )

testWindowEnd :: (String, Check)
testWindowEnd =
  ( "window at the end"
  , let win = windowAround 3 9 [1 .. 10 :: Int]
    in do
      checkEqual "above" True (windowAbove win)
      checkEqual "items" [8, 9, 10] (windowItems win)
      checkEqual "below" False (windowBelow win)
  )


testTruncate :: (String, Check)
testTruncate =
  ( "truncate visible"
  , do
      checkEqual "short" "short" (truncateVisible 10 "short")
      checkEqual "long" "abcd…" (truncateVisible 5 "abcdefgh")
  )

testInitialState :: (String, Check)
testInitialState =
  ( "initial state"
  , do
      category <- fixtureCategory
      workspace <- fixtureWorkspace
      let app = initialAppState workspace
      checkEqual "category screen" CategoryScreen (uiScreen (appUi app))
      checkEqual "category selected" (Just (categoryId category)) (uiCategory (appUi app))
      checkEqual "row selected" 0 (rowIndexValue (uiRow (appUi app)))
  )

testCycleStatus :: (String, Check)
testCycleStatus =
  ( "cycle status"
  , do
      category <- fixtureCategory
      workspace <- fixtureWorkspace
      board <- rightOr (update (SelectCategory (categoryId category))
                                (initialAppState workspace))
      forward <- rightOr (update CycleSelected board)
      checkEqual "forward" (Just Doing)
        (taskStatus <$> findTask (TaskId 1) (appWorkspace forward))
  )

testFilter :: (String, Check)
testFilter =
  ( "state filter"
  , do
      category <- fixtureCategory
      workspace <- fixtureWorkspace
      board <- rightOr (update (SelectCategory (categoryId category))
                                (initialAppState workspace))
      down <- rightOr (update (MoveRow Next) board)
      doing <- rightOr (update CycleSelected down)
      checkEqual "all count" 2 (length (visibleTasks doing))
      todo <- rightOr (update CycleFilter doing)
      checkEqual "todo filter label" "Todo"
        (filterLabel (uiFilter (appUi todo)))
      checkEqual "todo count" 1 (length (visibleTasks todo))
      checkEqual "todo status" [Todo] (map taskStatus (visibleTasks todo))
      doingFiltered <- rightOr (update CycleFilter todo)
      checkEqual "doing filter label" "Doing"
        (filterLabel (uiFilter (appUi doingFiltered)))
      checkEqual "doing count" 1 (length (visibleTasks doingFiltered))
      done <- rightOr (update CycleFilter doingFiltered)
      checkEqual "done count" 0 (length (visibleTasks done))
      allAgain <- rightOr (update CycleFilter done)
      checkEqual "all again" ShowAll (uiFilter (appUi allAgain))
      checkEqual "all count again" 2 (length (visibleTasks allAgain))
  )

testEditTask :: (String, Check)
testEditTask =
  ( "edit task"
  , do
      workspace <- fixtureWorkspace
      title <- rightOr (mkTaskTitle "Edited title")
      content <- rightOr (mkTaskContent "Edited note")
      updated <- rightOr (editTask (TaskId 1) title content workspace)
      checkEqual "title" (Just "Edited title")
        (taskTitleText . taskTitle <$> findTask (TaskId 1) updated)
      checkEqual "content" (Just "Edited note")
        (taskContentText . taskContent <$> findTask (TaskId 1) updated)
      check "unknown task"
        (isLeft (editTask (TaskId 99) title content workspace))
  )

testEditBlankKeeps :: (String, Check)
testEditBlankKeeps =
  ( "edit blank keeps the current value"
  , do
      category <- fixtureCategory
      workspace <- fixtureWorkspace
      board <- rightOr (update (SelectCategory (categoryId category))
                                (initialAppState workspace))
      kept <- rightOr (update (SubmitEdit (TaskId 1) "" "") board)
      checkEqual "title kept" (Just "Write docs")
        (taskTitleText . taskTitle <$> findTask (TaskId 1) (appWorkspace kept))
      checkEqual "content kept" (Just "First note")
        (taskContentText . taskContent <$> findTask (TaskId 1) (appWorkspace kept))
      changed <- rightOr (update (SubmitEdit (TaskId 1) "New" "New note") board)
      checkEqual "title changed" (Just "New")
        (taskTitleText . taskTitle <$> findTask (TaskId 1) (appWorkspace changed))
      checkEqual "content changed" (Just "New note")
        (taskContentText . taskContent <$> findTask (TaskId 1) (appWorkspace changed))
  )

testMoveRow :: (String, Check)
testMoveRow =
  ( "move row"
  , do
      workspace <- fixtureWorkspace
      app <- rightOr (update (MoveRow Next) (initialAppState workspace))
      checkEqual "next row" 1 (rowIndexValue (uiRow (appUi app)))
      app' <- rightOr (update (MoveRow Next) app)
      checkEqual "row clamped" 1 (rowIndexValue (uiRow (appUi app')))
  )

testSubmitTask :: (String, Check)
testSubmitTask =
  ( "submit task"
  , do
      category <- fixtureCategory
      workspace <- fixtureWorkspace
      app <- rightOr (update (SubmitTask "New task" "Some note")
                            (initialAppState workspace))
      checkEqual "task count" 3 (length (workspaceTasks (appWorkspace app)))
      checkEqual "board restored" BoardScreen (uiScreen (appUi app))
      checkEqual "new task selected" 2 (rowIndexValue (uiRow (appUi app)))
      checkEqual "category kept" (Just (categoryId category)) (uiCategory (appUi app))
      case selectedTask app of
        Just task ->
          checkEqual "new task note" "Some note"
            (taskContentText (taskContent task))
        Nothing -> Left "no selected task"
  )

testSubmitCategory :: (String, Check)
testSubmitCategory =
  ( "submit category"
  , do
      workspace <- fixtureWorkspace
      app <- rightOr (update (SubmitCategory "Personal") (initialAppState workspace))
      checkEqual "category count" 2 (length (workspaceCategories (appWorkspace app)))
      checkEqual "category screen" CategoryScreen (uiScreen (appUi app))
      checkEqual "new category selected" (Just (CategoryId 2)) (uiCategory (appUi app))
  )

testSelectUnknownCategory :: (String, Check)
testSelectUnknownCategory =
  ( "select unknown category"
  , do
      workspace <- fixtureWorkspace
      check "unknown category accepted"
        (isLeft (update (SelectCategory (CategoryId 99)) (initialAppState workspace)))
  )

testAddTaskWithoutCategory :: (String, Check)
testAddTaskWithoutCategory =
  ( "add task without category"
  , do
      app <- rightOr (update OpenAddTask (initialAppState emptyWorkspace))
      case uiNotice (appUi app) of
        Just notice -> checkEqual "error notice" NoticeError (noticeKind notice)
        Nothing     -> Left "no notice"
  )

testOpenDetails :: (String, Check)
testOpenDetails =
  ( "open details"
  , do
      category <- fixtureCategory
      workspace <- fixtureWorkspace
      let app = withDataFile "board.tsv" (initialAppState workspace)
      board <- rightOr (update (SelectCategory (categoryId category)) app)
      details <- rightOr (update OpenDetails board)
      checkEqual "details screen" (DetailsScreen (TaskId 1))
        (uiScreen (appUi details))
      checkEqual "data file" "board.tsv" (appDataFile details)
  )

testTaskFormPrompts :: (String, Check)
testTaskFormPrompts =
  ( "task form prompts"
  , do
      category <- fixtureCategory
      workspace <- fixtureWorkspace
      let app = withDataFile "board.tsv" (initialAppState workspace)
      board <- rightOr (update (SelectCategory (categoryId category)) app)
      formApp <- rightOr (update OpenAddTask board)
      case snd (renderTaskForm defaultUiTheme formApp) of
        [titlePrompt, contentPrompt] -> do
          checkEqual "title row" 0 (promptRow titlePrompt)
          checkEqual "content row" 0 (promptRow contentPrompt)
          checkEqual "title column" (formNumber taskTitlePromptColumn)
            (promptColumn titlePrompt)
          checkEqual "content column" (formNumber taskContentPromptColumn)
            (promptColumn contentPrompt)
          checkEqual "consecutive sections"
            (promptSection titlePrompt + 1) (promptSection contentPrompt)
        _ -> Left "unexpected prompt count"
  )

testArrowKeys :: (String, Check)
testArrowKeys =
  ( "arrow keys"
  , do
      checkEqual "up" (Just (MoveRowCommand Previous))
        (commandForKey BoardScreen KeyUp)
      checkEqual "down" (Just (MoveRowCommand Next))
        (commandForKey BoardScreen KeyDown)
      checkEqual "left" Nothing
        (commandForKey BoardScreen KeyLeft)
      checkEqual "right" Nothing
        (commandForKey BoardScreen KeyRight)
      checkEqual "enter" (Just AddTaskCommand)
        (commandForKey BoardScreen KeyEnter)
      checkEqual "backspace" (Just BackCommand)
        (commandForKey BoardScreen KeyBackspace)
      checkEqual "space" (Just CycleCommand)
        (commandForKey BoardScreen (KeyCharacter ' '))
      checkEqual "escape" (Just BackCommand)
        (commandForKey BoardScreen KeyEscape)
      checkEqual "help up" Nothing
        (commandForKey HelpScreen KeyUp)
      checkEqual "board e edits" (Just EditTaskCommand)
        (commandForKey BoardScreen (KeyCharacter 'e'))
      checkEqual "board f filters" (Just CycleFilterCommand)
        (commandForKey BoardScreen (KeyCharacter 'f'))
      checkEqual "details e edits" (Just EditTaskCommand)
        (commandForKey (DetailsScreen (TaskId 1)) (KeyCharacter 'e'))
      checkEqual "details f is free" Nothing
        (commandForKey (DetailsScreen (TaskId 1)) (KeyCharacter 'f'))
  )

testBackActions :: (String, Check)
testBackActions =
  ( "back actions"
  , do
      checkEqual "board back" OpenCategories (backAction BoardScreen)
      checkEqual "details back" OpenBoard
        (backAction (DetailsScreen (TaskId 1)))
      checkEqual "edit back" OpenBoard
        (backAction (EditTaskScreen (TaskId 1)))
      checkEqual "category back" OpenBoard (backAction CategoryScreen)
  )

testDeleteKey :: (String, Check)
testDeleteKey =
  ( "delete key"
  , do
      checkEqual "board delete" (Just DeleteCommand)
        (commandForKey BoardScreen KeyDelete)
      checkEqual "details delete" (Just DeleteCommand)
        (commandForKey (DetailsScreen (TaskId 1)) KeyDelete)
      checkEqual "d is not delete" Nothing
        (commandForKey BoardScreen (KeyCharacter 'd'))
      checkEqual "delete on help" Nothing
        (commandForKey HelpScreen KeyDelete)
  )

testWsKeys :: (String, Check)
testWsKeys =
  ( "ws navigation"
  , do
      checkEqual "w" (Just (MoveRowCommand Previous))
        (commandForKey BoardScreen (KeyCharacter 'w'))
      checkEqual "s" (Just (MoveRowCommand Next))
        (commandForKey BoardScreen (KeyCharacter 's'))
  )

-- Main.
--------------------------------------------------------------------------------

main :: IO ()
main =
  case [ (name, message) | (name, Left message) <- tests ] of
    [] -> putStrLn ("All " <> show (length tests) <> " tests passed.")
    failures -> do
      mapM_ report failures
      exitFailure

report :: (String, String) -> IO ()
report (name, message) =
  putStrLn ("FAIL: " <> name <> ": " <> message)
