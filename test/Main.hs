-- | Pure tests for the domain, persistence and update rules.
module Main (main) where

--------------------------------------------------------------------------------
import Numeric.Natural (Natural)
import System.Exit (exitFailure)

import Ansiform
    ( formNumber
    , promptColumn
    , promptInitial
    , promptRow
    , promptSection
    )

import Ansido.App.Command (Command (..), Key (..), commandForKey)
import Ansido.App.State
import Ansido.App.Update (backAction, update)
import Ansido.Domain
import Ansido.Persistence
import Ansido.Ui.Components
    ( Notice (..)
    , NoticeKind (..)
    , truncateVisible
    )
import Ansido.Ui.Page
    ( Window (..)
    , categoryPromptColumn
    , renderCategoryForm
    , renderTaskForm
    , taskContentPromptColumn
    , taskTitlePromptColumn
    , windowAround
    )
import Ansido.Ui.Theme (defaultUiTheme)

-- Harness.
--------------------------------------------------------------------------------

type Check = Either String ()

check :: String -> Bool -> Check
check label condition =
    if condition then Right () else Left label

checkEqual :: (Eq a, Show a) => String -> a -> a -> Check
checkEqual label expected actual
    | expected == actual = Right ()
    | otherwise =
        Left
            (label <> ": expected " <> show expected <> ", got " <> show actual)

rightOr :: (Show e) => Either e a -> Either String a
rightOr result =
    case result of
        Left err -> Left (show err)
        Right value -> Right value

isLeft :: Either a b -> Bool
isLeft result =
    case result of
        Left _ -> True
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

mustCategoryId :: Natural -> Either String CategoryId
mustCategoryId = rightOr . mkCategoryId

mustTaskId :: Natural -> Either String TaskId
mustTaskId = rightOr . mkTaskId

-- | Two tasks whose status and title orders differ.
sortFixture :: Either String (Category, Workspace)
sortFixture = do
    name <- rightOr (mkCategoryName "Work")
    (category, workspace1) <- rightOr (addCategory name emptyWorkspace)
    titleAlpha <- rightOr (mkTaskTitle "Alpha")
    titleZeta <- rightOr (mkTaskTitle "Zeta")
    emptyNote <- rightOr (mkTaskContent "")
    (taskAlpha, workspace2) <-
        rightOr (addTask (categoryId category) titleAlpha emptyNote workspace1)
    (_, workspace3) <-
        rightOr (addTask (categoryId category) titleZeta emptyNote workspace2)
    workspace4 <- rightOr (moveTask (taskId taskAlpha) Doing workspace3)
    pure (category, workspace4)

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
    , testEditCategory
    , testDeleteCategory
    , testSubmitCategoryEdit
    , testDeleteSelectedCategory
    , testDuplicateCategory
    , testWorkspaceInvariants
    , testIdentifierValidation
    , testEncodeDecode
    , testDecodeEmpty
    , testDecodeBadHeader
    , testDecodeBadStatus
    , testDecodeInvalidId
    , testDecodeVersion1
    , testDecodeCrlf
    , testWindowStart
    , testWindowMiddle
    , testWindowEnd
    , testTruncate
    , testInitialState
    , testCycleStatus
    , testFilter
    , testSortOrder
    , testSortKeepsSelection
    , testStatusSortKeepsSelection
    , testEditTask
    , testEditValues
    , testMoveRow
    , testMoveCategory
    , testSubmitTask
    , testSubmitCategory
    , testSelectUnknownCategory
    , testAddTaskWithoutCategory
    , testOpenDetails
    , testTaskFormPrompts
    , testCategoryFormPrompts
    , testArrowKeys
    , testDeleteKey
    , testWsKeys
    , testBackActions
    , testCategoryKeys
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
        check
            "long content accepted"
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
        unknownCategory <- mustCategoryId 99
        title <- rightOr (mkTaskTitle "Review")
        content <- rightOr (mkTaskContent "Note")
        check
            "unknown category accepted"
            (isLeft (addTask unknownCategory title content workspace))
    )

testMoveTask :: (String, Check)
testMoveTask =
    ( "move task"
    , do
        workspace <- fixtureWorkspace
        task1 <- mustTaskId 1
        task2 <- mustTaskId 2
        updated <- rightOr (moveTask task1 Doing workspace)
        checkEqual "first task moved" (Just Doing) (taskStatus <$> findTask task1 updated)
        checkEqual "second task untouched" (Just Todo) (taskStatus <$> findTask task2 updated)
    )

testAdvanceTaskCycle :: (String, Check)
testAdvanceTaskCycle =
    ( "advance task cycle"
    , do
        workspace <- fixtureWorkspace
        task1 <- mustTaskId 1
        once <- rightOr (advanceTask task1 workspace)
        twice <- rightOr (advanceTask task1 once)
        thrice <- rightOr (advanceTask task1 twice)
        checkEqual "todo to doing" (Just Doing) (taskStatus <$> findTask task1 once)
        checkEqual "doing to done" (Just Done) (taskStatus <$> findTask task1 twice)
        checkEqual "done to todo" (Just Todo) (taskStatus <$> findTask task1 thrice)
    )

testDeleteTask :: (String, Check)
testDeleteTask =
    ( "delete task"
    , do
        workspace <- fixtureWorkspace
        task1 <- mustTaskId 1
        task2 <- mustTaskId 2
        updated <- rightOr (deleteTask task1 workspace)
        checkEqual "task removed" Nothing (findTask task1 updated)
        checkEqual "other task kept" (Just task2) (taskId <$> findTask task2 updated)
    )

testEditCategory :: (String, Check)
testEditCategory =
    ( "edit category"
    , do
        category <- fixtureCategory
        workspace <- fixtureWorkspace
        name <- rightOr (mkCategoryName "Personal")
        updated <- rightOr (editCategory (categoryId category) name workspace)
        checkEqual
            "name"
            (Just "Personal")
            ( categoryNameText . categoryName
                <$> findCategory (categoryId category) updated
            )
        unchanged <-
            rightOr
                ( editCategory
                    (categoryId category)
                    (categoryName category)
                    workspace
                )
        checkEqual
            "same name kept"
            (workspaceCategories workspace)
            (workspaceCategories unchanged)
        (_, twoCategories) <- rightOr (addCategory name workspace)
        check
            "duplicate name accepted"
            (isLeft (editCategory (categoryId category) name twoCategories))
        unknownCategory <- mustCategoryId 99
        check
            "unknown category"
            (isLeft (editCategory unknownCategory name workspace))
    )

testDeleteCategory :: (String, Check)
testDeleteCategory =
    ( "delete category"
    , do
        category <- fixtureCategory
        workspace <- fixtureWorkspace
        otherName <- rightOr (mkCategoryName "Personal")
        (other, twoCategories) <- rightOr (addCategory otherName workspace)
        title <- rightOr (mkTaskTitle "Kept task")
        content <- rightOr (mkTaskContent "Kept note")
        (keptTask, withOtherTask) <-
            rightOr (addTask (categoryId other) title content twoCategories)
        updated <- rightOr (deleteCategory (categoryId category) withOtherTask)
        checkEqual
            "category removed"
            Nothing
            (findCategory (categoryId category) updated)
        checkEqual
            "own tasks removed"
            [taskId keptTask]
            (map taskId (workspaceTasks updated))
        unknownCategory <- mustCategoryId 99
        check
            "unknown category"
            (isLeft (deleteCategory unknownCategory withOtherTask))
    )

testSubmitCategoryEdit :: (String, Check)
testSubmitCategoryEdit =
    ( "submit category edit"
    , do
        category <- fixtureCategory
        workspace <- fixtureWorkspace
        renamed <-
            rightOr
                ( update
                    (SubmitCategoryEdit (categoryId category) "Office")
                    (initialAppState workspace)
                )
        checkEqual
            "renamed"
            (Just "Office")
            ( categoryNameText . categoryName
                <$> findCategory (categoryId category) (appWorkspace renamed)
            )
        checkEqual "category screen" CategoryScreen (uiScreen (appUi renamed))
        checkEqual
            "selection kept"
            (Just (categoryId category))
            (uiCategory (appUi renamed))
        check
            "empty name rejected"
            ( isLeft
                ( update
                    (SubmitCategoryEdit (categoryId category) "   ")
                    (initialAppState workspace)
                )
            )
    )

testDeleteSelectedCategory :: (String, Check)
testDeleteSelectedCategory =
    ( "delete selected category"
    , do
        workspace <- fixtureWorkspace
        app <-
            rightOr
                ( update
                    DeleteSelectedCategory
                    (initialAppState workspace)
                )
        checkEqual "categories removed" [] (workspaceCategories (appWorkspace app))
        checkEqual "tasks removed" [] (workspaceTasks (appWorkspace app))
        checkEqual "category screen" CategoryScreen (uiScreen (appUi app))
        checkEqual "selection cleared" Nothing (uiCategory (appUi app))
        case uiNotice (appUi app) of
            Just notice ->
                checkEqual "info notice" NoticeInfo (noticeKind notice)
            Nothing -> Left "no notice"
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
        taskIdentifier <- mustTaskId 1
        unknownCategory <- mustCategoryId 99
        title <- rightOr (mkTaskTitle "x")
        content <- rightOr (mkTaskContent "")
        let categoryDuplicate = mkCategory (categoryId category) (categoryName category)
            task = mkTask taskIdentifier title content Todo unknownCategory
        check
            "duplicate category id accepted"
            (isLeft (mkWorkspace [category, categoryDuplicate] (workspaceTasks workspace)))
        check
            "unknown category accepted"
            (isLeft (mkWorkspace [category] [task]))
    )

testIdentifierValidation :: (String, Check)
testIdentifierValidation =
    ( "identifier validation"
    , do
        check "zero category id rejected" (isLeft (mkCategoryId 0))
        check "zero task id rejected" (isLeft (mkTaskId 0))
        categoryIdentifier <- mustCategoryId 1
        taskIdentifier <- mustTaskId 1
        checkEqual "category id" 1 (categoryIdValue categoryIdentifier)
        checkEqual "task id" 1 (taskIdValue taskIdentifier)
        checkEqual "negative row clamped" 0 (rowIndexValue (mkRowIndex (-1)))
        checkEqual "positive row kept" 2 (rowIndexValue (mkRowIndex 2))
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
    , check
        "bad status accepted"
        (isLeft (decodeWorkspace "ansido\t1\ntask\t1\t1\tlater\tTitle\n"))
    )

testDecodeInvalidId :: (String, Check)
testDecodeInvalidId =
    ( "decode invalid identifiers"
    , do
        check
            "zero category id"
            (isLeft (decodeWorkspace "ansido\t2\ncategory\t0\tWork\n"))
        check
            "negative category id"
            (isLeft (decodeWorkspace "ansido\t2\ncategory\t-1\tWork\n"))
        check
            "zero task id"
            ( isLeft
                ( decodeWorkspace
                    "ansido\t2\ncategory\t1\tWork\ntask\t0\t1\ttodo\tTitle\t\n"
                )
            )
    )

testDecodeVersion1 :: (String, Check)
testDecodeVersion1 =
    ( "decode version 1"
    , case decodeWorkspace
        "ansido\t1\ncategory\t1\tWork\ntask\t1\t1\ttodo\tLegacy\n" of
        Left err -> Left (show err)
        Right workspace -> do
            task1 <- mustTaskId 1
            case findTask task1 workspace of
                Nothing -> Left "task missing"
                Just task ->
                    checkEqual
                        "legacy content"
                        ""
                        (taskContentText (taskContent task))
    )

testDecodeCrlf :: (String, Check)
testDecodeCrlf =
    ( "decode CRLF files"
    , do
        workspace <- fixtureWorkspace
        let crlf =
                concatMap
                    (\char -> if char == '\n' then "\r\n" else [char])
                    (encodeWorkspace workspace)
        checkEqual "crlf roundtrip" (Right workspace) (decodeWorkspace crlf)
        checkEqual
            "no carriage return on encode"
            False
            (elem '\r' (encodeWorkspace workspace))
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
        board <-
            rightOr
                ( update
                    (SelectCategory (categoryId category))
                    (initialAppState workspace)
                )
        forward <- rightOr (update CycleSelected board)
        task1 <- mustTaskId 1
        checkEqual
            "forward"
            (Just Doing)
            (taskStatus <$> findTask task1 (appWorkspace forward))
    )

testFilter :: (String, Check)
testFilter =
    ( "state filter"
    , do
        category <- fixtureCategory
        workspace <- fixtureWorkspace
        board <-
            rightOr
                ( update
                    (SelectCategory (categoryId category))
                    (initialAppState workspace)
                )
        down <- rightOr (update (MoveRow Next) board)
        doing <- rightOr (update CycleSelected down)
        checkEqual "all count" 2 (length (visibleTasks doing))
        todo <- rightOr (update CycleFilter doing)
        checkEqual
            "todo filter label"
            "Todo"
            (filterLabel (uiFilter (appUi todo)))
        checkEqual "todo count" 1 (length (visibleTasks todo))
        checkEqual "todo status" [Todo] (map taskStatus (visibleTasks todo))
        doingFiltered <- rightOr (update CycleFilter todo)
        checkEqual
            "doing filter label"
            "Doing"
            (filterLabel (uiFilter (appUi doingFiltered)))
        checkEqual "doing count" 1 (length (visibleTasks doingFiltered))
        done <- rightOr (update CycleFilter doingFiltered)
        checkEqual "done count" 0 (length (visibleTasks done))
        allAgain <- rightOr (update CycleFilter done)
        checkEqual "all again" ShowAll (uiFilter (appUi allAgain))
        checkEqual "all count again" 2 (length (visibleTasks allAgain))
    )

testSortOrder :: (String, Check)
testSortOrder =
    ( "sort order"
    , do
        sorted <- rightOr sortFixture
        let category = fst sorted
            workspace = snd sorted
        task1 <- mustTaskId 1
        task2 <- mustTaskId 2
        board <-
            rightOr
                ( update
                    (SelectCategory (categoryId category))
                    (initialAppState workspace)
                )
        checkEqual
            "original order"
            [task1, task2]
            (map taskId (visibleTasks board))
        byStatus <- rightOr (update CycleSort board)
        checkEqual "status sort" SortByStatus (uiSort (appUi byStatus))
        checkEqual "status label" "status" (sortLabel (uiSort (appUi byStatus)))
        checkEqual
            "status order"
            [task2, task1]
            (map taskId (visibleTasks byStatus))
        byTitle <- rightOr (update CycleSort byStatus)
        checkEqual "title sort" SortByTitle (uiSort (appUi byTitle))
        checkEqual "title label" "title" (sortLabel (uiSort (appUi byTitle)))
        checkEqual
            "title order"
            [task1, task2]
            (map taskId (visibleTasks byTitle))
        backToOriginal <- rightOr (update CycleSort byTitle)
        checkEqual "original again" SortOriginal (uiSort (appUi backToOriginal))
        checkEqual "original label" "original" (sortLabel (uiSort (appUi backToOriginal)))
        checkEqual
            "original order again"
            [task1, task2]
            (map taskId (visibleTasks backToOriginal))
    )

testSortKeepsSelection :: (String, Check)
testSortKeepsSelection =
    ( "sort keeps selection"
    , do
        sorted <- rightOr sortFixture
        let category = fst sorted
            workspace = snd sorted
        task1 <- mustTaskId 1
        board <-
            rightOr
                ( update
                    (SelectCategory (categoryId category))
                    (initialAppState workspace)
                )
        checkEqual "initial selection" (Just task1) (selectedTaskId board)
        byStatus <- rightOr (update CycleSort board)
        checkEqual "selection kept after sort" (Just task1) (selectedTaskId byStatus)
        checkEqual "row follows the task" 1 (rowIndexValue (uiRow (appUi byStatus)))
        byTitle <- rightOr (update CycleSort byStatus)
        checkEqual "selection kept after title sort" (Just task1) (selectedTaskId byTitle)
        checkEqual "row follows the title" 0 (rowIndexValue (uiRow (appUi byTitle)))
    )

testStatusSortKeepsSelection :: (String, Check)
testStatusSortKeepsSelection =
    ( "status change keeps selection under sort"
    , do
        category <- fixtureCategory
        workspace <- fixtureWorkspace
        task1 <- mustTaskId 1
        task2 <- mustTaskId 2
        task3 <- mustTaskId 3
        title <- rightOr (mkTaskTitle "Gamma")
        content <- rightOr (mkTaskContent "")
        (thirdTask, withThird) <-
            rightOr (addTask (categoryId category) title content workspace)
        moved <- rightOr (moveTask (taskId thirdTask) Doing withThird)
        board <-
            rightOr
                ( update
                    (SelectCategory (categoryId category))
                    (initialAppState moved)
                )
        byStatus <- rightOr (update CycleSort board)
        checkEqual
            "status order before the change"
            [task1, task2, task3]
            (map taskId (visibleTasks byStatus))
        changed <- rightOr (update CycleSelected byStatus)
        checkEqual
            "status order after the change"
            [task2, task1, task3]
            (map taskId (visibleTasks changed))
        checkEqual "selection follows the status" (Just task1) (selectedTaskId changed)
        checkEqual "row follows the status" 1 (rowIndexValue (uiRow (appUi changed)))
    )

testEditTask :: (String, Check)
testEditTask =
    ( "edit task"
    , do
        workspace <- fixtureWorkspace
        task1 <- mustTaskId 1
        unknownTask <- mustTaskId 99
        title <- rightOr (mkTaskTitle "Edited title")
        content <- rightOr (mkTaskContent "Edited note")
        updated <- rightOr (editTask task1 title content workspace)
        checkEqual
            "title"
            (Just "Edited title")
            (taskTitleText . taskTitle <$> findTask task1 updated)
        checkEqual
            "content"
            (Just "Edited note")
            (taskContentText . taskContent <$> findTask task1 updated)
        check
            "unknown task"
            (isLeft (editTask unknownTask title content workspace))
    )

testEditValues :: (String, Check)
testEditValues =
    ( "edit task values"
    , do
        category <- fixtureCategory
        workspace <- fixtureWorkspace
        task1 <- mustTaskId 1
        board <-
            rightOr
                ( update
                    (SelectCategory (categoryId category))
                    (initialAppState workspace)
                )
        changed <- rightOr (update (SubmitEdit task1 "New" "New note") board)
        checkEqual
            "title changed"
            (Just "New")
            (taskTitleText . taskTitle <$> findTask task1 (appWorkspace changed))
        checkEqual
            "content changed"
            (Just "New note")
            (taskContentText . taskContent <$> findTask task1 (appWorkspace changed))
        cleared <- rightOr (update (SubmitEdit task1 "New" "") board)
        checkEqual
            "note cleared"
            (Just "")
            (taskContentText . taskContent <$> findTask task1 (appWorkspace cleared))
        check
            "empty title rejected"
            (isLeft (update (SubmitEdit task1 "" "Note") board))
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

testMoveCategory :: (String, Check)
testMoveCategory =
    ( "move category"
    , do
        workspace <- fixtureWorkspace
        name <- rightOr (mkCategoryName "Personal")
        (_, twoCategories) <- rightOr (addCategory name workspace)
        category1 <- mustCategoryId 1
        category2 <- mustCategoryId 2
        let app = initialAppState twoCategories
        next <- rightOr (update (MoveCategory Next) app)
        checkEqual "next category" (Just category2) (uiCategory (appUi next))
        checkEqual "category screen kept" CategoryScreen (uiScreen (appUi next))
        checkEqual "row reset" 0 (rowIndexValue (uiRow (appUi next)))
        clamped <- rightOr (update (MoveCategory Next) next)
        checkEqual
            "last category clamped"
            (Just category2)
            (uiCategory (appUi clamped))
        previous <- rightOr (update (MoveCategory Previous) clamped)
        checkEqual
            "previous category"
            (Just category1)
            (uiCategory (appUi previous))
        first <- rightOr (update (MoveCategory Previous) previous)
        checkEqual
            "first category clamped"
            (Just category1)
            (uiCategory (appUi first))
        empty <- rightOr (update (MoveCategory Next) (initialAppState emptyWorkspace))
        checkEqual
            "no category on empty workspace"
            Nothing
            (uiCategory (appUi empty))
    )

testSubmitTask :: (String, Check)
testSubmitTask =
    ( "submit task"
    , do
        category <- fixtureCategory
        workspace <- fixtureWorkspace
        app <-
            rightOr
                ( update
                    (SubmitTask "New task" "Some note")
                    (initialAppState workspace)
                )
        checkEqual "task count" 3 (length (workspaceTasks (appWorkspace app)))
        checkEqual "board restored" BoardScreen (uiScreen (appUi app))
        checkEqual "new task selected" 2 (rowIndexValue (uiRow (appUi app)))
        checkEqual "category kept" (Just (categoryId category)) (uiCategory (appUi app))
        case selectedTask app of
            Just task ->
                checkEqual
                    "new task note"
                    "Some note"
                    (taskContentText (taskContent task))
            Nothing -> Left "no selected task"
    )

testSubmitCategory :: (String, Check)
testSubmitCategory =
    ( "submit category"
    , do
        workspace <- fixtureWorkspace
        app <- rightOr (update (SubmitCategory "Personal") (initialAppState workspace))
        category2 <- mustCategoryId 2
        checkEqual "category count" 2 (length (workspaceCategories (appWorkspace app)))
        checkEqual "category screen" CategoryScreen (uiScreen (appUi app))
        checkEqual "new category selected" (Just category2) (uiCategory (appUi app))
    )

testSelectUnknownCategory :: (String, Check)
testSelectUnknownCategory =
    ( "select unknown category"
    , do
        workspace <- fixtureWorkspace
        unknownCategory <- mustCategoryId 99
        check
            "unknown category accepted"
            (isLeft (update (SelectCategory unknownCategory) (initialAppState workspace)))
    )

testAddTaskWithoutCategory :: (String, Check)
testAddTaskWithoutCategory =
    ( "add task without category"
    , do
        app <- rightOr (update OpenAddTask (initialAppState emptyWorkspace))
        case uiNotice (appUi app) of
            Just notice -> checkEqual "error notice" NoticeError (noticeKind notice)
            Nothing -> Left "no notice"
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
        task1 <- mustTaskId 1
        checkEqual
            "details screen"
            (DetailsScreen task1)
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
                checkEqual
                    "title column"
                    (formNumber taskTitlePromptColumn)
                    (promptColumn titlePrompt)
                checkEqual
                    "content column"
                    (formNumber taskContentPromptColumn)
                    (promptColumn contentPrompt)
                checkEqual
                    "consecutive sections"
                    (promptSection titlePrompt + 1)
                    (promptSection contentPrompt)
                checkEqual
                    "title has an empty editable buffer"
                    (Just "")
                    (promptInitial titlePrompt)
                checkEqual
                    "content has an empty editable buffer"
                    (Just "")
                    (promptInitial contentPrompt)
            _ -> Left "unexpected prompt count"
        editApp <- rightOr (update OpenEditTask board)
        case snd (renderTaskForm defaultUiTheme editApp) of
            [titlePrompt, contentPrompt] -> do
                checkEqual
                    "edit title initial"
                    (Just "Write docs")
                    (promptInitial titlePrompt)
                checkEqual
                    "edit content initial"
                    (Just "First note")
                    (promptInitial contentPrompt)
            _ -> Left "unexpected edit prompt count"
    )

testCategoryFormPrompts :: (String, Check)
testCategoryFormPrompts =
    ( "category form prompts"
    , do
        workspace <- fixtureWorkspace
        let app = initialAppState workspace
        addApp <- rightOr (update OpenAddCategory app)
        editApp <- rightOr (update OpenEditCategory app)
        case ( snd (renderCategoryForm defaultUiTheme addApp)
             , snd (renderCategoryForm defaultUiTheme editApp)
             ) of
            ([addPrompt], [editPrompt]) -> do
                checkEqual "row" 0 (promptRow addPrompt)
                checkEqual
                    "column"
                    (formNumber categoryPromptColumn)
                    (promptColumn addPrompt)
                checkEqual "edit row" 0 (promptRow editPrompt)
                checkEqual
                    "edit column"
                    (formNumber categoryPromptColumn)
                    (promptColumn editPrompt)
                checkEqual
                    "edit prompt below the hint"
                    (promptSection addPrompt + 1)
                    (promptSection editPrompt)
                checkEqual
                    "add has an empty editable buffer"
                    (Just "")
                    (promptInitial addPrompt)
                checkEqual
                    "edit initial name"
                    (Just "Work")
                    (promptInitial editPrompt)
            _ -> Left "unexpected prompt count"
    )

testArrowKeys :: (String, Check)
testArrowKeys =
    ( "arrow keys"
    , do
        task1 <- mustTaskId 1
        checkEqual
            "up"
            (Just (MoveRowCommand Previous))
            (commandForKey BoardScreen KeyUp)
        checkEqual
            "down"
            (Just (MoveRowCommand Next))
            (commandForKey BoardScreen KeyDown)
        checkEqual
            "left"
            Nothing
            (commandForKey BoardScreen KeyLeft)
        checkEqual
            "right"
            Nothing
            (commandForKey BoardScreen KeyRight)
        checkEqual
            "enter"
            (Just AddTaskCommand)
            (commandForKey BoardScreen KeyEnter)
        checkEqual
            "backspace"
            (Just BackCommand)
            (commandForKey BoardScreen KeyBackspace)
        checkEqual
            "space"
            (Just CycleCommand)
            (commandForKey BoardScreen (KeyCharacter ' '))
        checkEqual
            "escape"
            (Just BackCommand)
            (commandForKey BoardScreen KeyEscape)
        checkEqual
            "help up"
            Nothing
            (commandForKey HelpScreen KeyUp)
        checkEqual
            "board e edits"
            (Just EditTaskCommand)
            (commandForKey BoardScreen (KeyCharacter 'e'))
        checkEqual
            "board f filters"
            (Just CycleFilterCommand)
            (commandForKey BoardScreen (KeyCharacter 'f'))
        checkEqual
            "board o sorts"
            (Just CycleSortCommand)
            (commandForKey BoardScreen (KeyCharacter 'o'))
        checkEqual
            "details v goes back"
            (Just BackCommand)
            (commandForKey (DetailsScreen task1) (KeyCharacter 'v'))
        checkEqual
            "board v opens details"
            (Just DetailsCommand)
            (commandForKey BoardScreen (KeyCharacter 'v'))
        checkEqual
            "details e edits"
            (Just EditTaskCommand)
            (commandForKey (DetailsScreen task1) (KeyCharacter 'e'))
        checkEqual
            "details f is free"
            Nothing
            (commandForKey (DetailsScreen task1) (KeyCharacter 'f'))
        checkEqual
            "details o is free"
            Nothing
            (commandForKey (DetailsScreen task1) (KeyCharacter 'o'))
    )

testBackActions :: (String, Check)
testBackActions =
    ( "back actions"
    , do
        task1 <- mustTaskId 1
        category1 <- mustCategoryId 1
        checkEqual "board back" OpenCategories (backAction BoardScreen)
        checkEqual
            "details back"
            OpenBoard
            (backAction (DetailsScreen task1))
        checkEqual
            "edit back"
            OpenBoard
            (backAction (EditTaskScreen task1))
        checkEqual "category back" OpenBoard (backAction CategoryScreen)
        checkEqual
            "edit category back"
            OpenCategories
            (backAction (EditCategoryScreen category1))
    )

testDeleteKey :: (String, Check)
testDeleteKey =
    ( "delete key"
    , do
        task1 <- mustTaskId 1
        checkEqual
            "board delete"
            (Just DeleteCommand)
            (commandForKey BoardScreen KeyDelete)
        checkEqual
            "details delete"
            (Just DeleteCommand)
            (commandForKey (DetailsScreen task1) KeyDelete)
        checkEqual
            "d is not delete"
            Nothing
            (commandForKey BoardScreen (KeyCharacter 'd'))
        checkEqual
            "delete on help"
            Nothing
            (commandForKey HelpScreen KeyDelete)
    )

testWsKeys :: (String, Check)
testWsKeys =
    ( "ws navigation"
    , do
        checkEqual
            "w"
            (Just (MoveRowCommand Previous))
            (commandForKey BoardScreen (KeyCharacter 'w'))
        checkEqual
            "s"
            (Just (MoveRowCommand Next))
            (commandForKey BoardScreen (KeyCharacter 's'))
    )

testCategoryKeys :: (String, Check)
testCategoryKeys =
    ( "category keys"
    , do
        category1 <- mustCategoryId 1
        checkEqual
            "n creates"
            (Just AddCategoryCommand)
            (commandForKey CategoryScreen (KeyCharacter 'n'))
        checkEqual
            "e edits"
            (Just EditCategoryCommand)
            (commandForKey CategoryScreen (KeyCharacter 'e'))
        checkEqual
            "delete removes a category"
            (Just DeleteCategoryCommand)
            (commandForKey CategoryScreen KeyDelete)
        checkEqual
            "up moves the highlight"
            (Just (MoveCategoryCommand Previous))
            (commandForKey CategoryScreen KeyUp)
        checkEqual
            "down moves the highlight"
            (Just (MoveCategoryCommand Next))
            (commandForKey CategoryScreen KeyDown)
        checkEqual
            "k moves up"
            (Just (MoveCategoryCommand Previous))
            (commandForKey CategoryScreen (KeyCharacter 'k'))
        checkEqual
            "j moves down"
            (Just (MoveCategoryCommand Next))
            (commandForKey CategoryScreen (KeyCharacter 'j'))
        checkEqual
            "enter opens the board"
            (Just OpenBoardCommand)
            (commandForKey CategoryScreen KeyEnter)
        checkEqual
            "digits select"
            (Just (SelectCategoryCommand 2))
            (commandForKey CategoryScreen (KeyCharacter '2'))
        checkEqual
            "edit form ignores e"
            Nothing
            (commandForKey (EditCategoryScreen category1) (KeyCharacter 'e'))
        checkEqual
            "edit form confirms with enter"
            Nothing
            (commandForKey (EditCategoryScreen category1) KeyEnter)
    )

-- Main.
--------------------------------------------------------------------------------

main :: IO ()
main =
    case [(name, message) | (name, Left message) <- tests] of
        [] -> putStrLn ("All " <> show (length tests) <> " tests passed.")
        failures -> do
            mapM_ report failures
            exitFailure

report :: (String, String) -> IO ()
report (name, message) =
    putStrLn ("FAIL: " <> name <> ": " <> message)
