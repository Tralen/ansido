-- | Pure tests for the domain, persistence and update rules.
module Main (main) where

--------------------------------------------------------------------------------
import           System.Exit (exitFailure)

import           Ansido.App.Command (Command (..), Key (..), commandForKey)
import           Ansido.App.State
import           Ansido.App.Update (backAction, update)
import           Ansido.Domain
import           Ansido.Persistence
import           Ansido.Ui.Components (Notice (..), NoticeKind (..),
                                       truncateVisible)
import           Ansido.Ui.Page (Window (..), windowAround)

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
  , testTruncateShort
  , testTruncateLong
  , testInitialState
  , testMoveColumn
  , testMoveRow
  , testSubmitTask
  , testSubmitCategory
  , testSelectUnknownCategory
  , testAddTaskWithoutCategory
  , testDetailsWithoutSelection
  , testArrowKeys
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

testTruncateShort :: (String, Check)
testTruncateShort =
  ( "truncate short text"
  , checkEqual "unchanged" "short" (truncateVisible 10 "short")
  )

testTruncateLong :: (String, Check)
testTruncateLong =
  ( "truncate long text"
  , checkEqual "ellipsis" "ab..." (truncateVisible 5 "abcdefgh")
  )

testInitialState :: (String, Check)
testInitialState =
  ( "initial state"
  , do
      category <- fixtureCategory
      workspace <- fixtureWorkspace
      let app = initialAppState workspace
      checkEqual "category selected" (Just (categoryId category)) (uiCategory (appUi app))
      checkEqual "status selected" Todo (uiStatus (appUi app))
      checkEqual "row selected" 0 (rowIndexValue (uiRow (appUi app)))
  )

testMoveColumn :: (String, Check)
testMoveColumn =
  ( "move column"
  , do
      workspace <- fixtureWorkspace
      app <- rightOr (update (MoveColumn Next) (initialAppState workspace))
      checkEqual "next column" Doing (uiStatus (appUi app))
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

testDetailsWithoutSelection :: (String, Check)
testDetailsWithoutSelection =
  ( "details without selection"
  , do
      app <- rightOr (update OpenDetails (initialAppState emptyWorkspace))
      case uiNotice (appUi app) of
        Just notice -> checkEqual "info notice" NoticeInfo (noticeKind notice)
        Nothing     -> Left "no notice"
  )

testArrowKeys :: (String, Check)
testArrowKeys =
  ( "arrow keys"
  , do
      checkEqual "up" (Just (MoveRowCommand Previous))
        (commandForKey BoardScreen KeyUp)
      checkEqual "down" (Just (MoveRowCommand Next))
        (commandForKey BoardScreen KeyDown)
      checkEqual "left" (Just (MoveColumnCommand Previous))
        (commandForKey BoardScreen KeyLeft)
      checkEqual "right" (Just (MoveColumnCommand Next))
        (commandForKey BoardScreen KeyRight)
      checkEqual "escape" (Just BackCommand)
        (commandForKey BoardScreen KeyEscape)
      checkEqual "details up" Nothing
        (commandForKey (DetailsScreen (TaskId 1)) KeyUp)
  )

testBackActions :: (String, Check)
testBackActions =
  ( "back actions"
  , do
      checkEqual "board back" OpenCategories (backAction BoardScreen)
      checkEqual "details back" OpenBoard
        (backAction (DetailsScreen (TaskId 1)))
      checkEqual "category back" OpenBoard (backAction CategoryScreen)
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
