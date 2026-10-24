-- | Mapping from key presses to commands.
--
-- Command resolution is pure. Actions that need text input are started by
-- the runner, which owns the line input and the persistence edge.
module Ansido.App.Command
    ( Key (..)
    , Command (..)
    , commandForKey
    ) where

--------------------------------------------------------------------------------
import Data.Char (digitToInt, isDigit, toLower)

import Ansido.App.State (Direction (..), Screen (..))

-- | A decoded terminal key, with arrows and Delete separated from sequences.
data Key
    = KeyCharacter Char
    | KeyUp
    | KeyDown
    | KeyLeft
    | KeyRight
    | KeyDelete
    | KeyEnter
    | KeyBackspace
    | KeyEscape
    deriving (Eq, Show)

-- | High level commands produced by the keyboard.
data Command
    = QuitCommand
    | RedrawCommand
    | HelpCommand
    | BackCommand
    | CategoriesCommand
    | DetailsCommand
    | EditTaskCommand
    | AddTaskCommand
    | AddCategoryCommand
    | EditCategoryCommand
    | DeleteCategoryCommand
    | CycleFilterCommand
    | CycleSortCommand
    | CycleCommand
    | DeleteCommand
    | MoveRowCommand Direction
    | MoveCategoryCommand Direction
    | OpenBoardCommand
    | SelectCategoryCommand Int
    deriving (Eq, Show)

-- | Resolves a key for the current screen.
commandForKey :: Screen -> Key -> Maybe Command
commandForKey screen key =
    case key of
        KeyEscape -> Just BackCommand
        KeyBackspace -> Just BackCommand
        KeyUp -> directionCommand screen Previous
        KeyDown -> directionCommand screen Next
        KeyLeft -> Nothing
        KeyRight -> Nothing
        KeyDelete -> deleteCommand screen
        KeyEnter -> enterCommand screen
        KeyCharacter char -> characterCommand screen char

directionCommand :: Screen -> Direction -> Maybe Command
directionCommand screen direction =
    case screen of
        BoardScreen -> Just (MoveRowCommand direction)
        CategoryScreen -> Just (MoveCategoryCommand direction)
        _ -> Nothing

enterCommand :: Screen -> Maybe Command
enterCommand screen =
    case screen of
        BoardScreen -> Just AddTaskCommand
        CategoryScreen -> Just OpenBoardCommand
        _ -> Nothing

deleteCommand :: Screen -> Maybe Command
deleteCommand screen =
    case screen of
        BoardScreen -> Just DeleteCommand
        DetailsScreen _ -> Just DeleteCommand
        CategoryScreen -> Just DeleteCategoryCommand
        _ -> Nothing

characterCommand :: Screen -> Char -> Maybe Command
characterCommand screen key =
    case key of
        'x' -> Just QuitCommand
        'X' -> Just QuitCommand
        'r' -> Just RedrawCommand
        'R' -> Just RedrawCommand
        _ ->
            case screen of
                BoardScreen -> boardCommand (toLower key)
                DetailsScreen _ -> detailsCommand (toLower key)
                EditTaskScreen _ -> Nothing
                HelpScreen -> helpCommand (toLower key)
                CategoryScreen -> categoryCommand key
                AddTaskScreen -> Nothing
                AddCategoryScreen -> Nothing
                EditCategoryScreen _ -> Nothing

boardCommand :: Char -> Maybe Command
boardCommand key =
    case key of
        ' ' -> Just CycleCommand
        'e' -> Just EditTaskCommand
        'f' -> Just CycleFilterCommand
        'o' -> Just CycleSortCommand
        'v' -> Just DetailsCommand
        'w' -> Just (MoveRowCommand Previous)
        's' -> Just (MoveRowCommand Next)
        'k' -> Just (MoveRowCommand Previous)
        'j' -> Just (MoveRowCommand Next)
        '?' -> Just HelpCommand
        _ -> Nothing

detailsCommand :: Char -> Maybe Command
detailsCommand key =
    case key of
        ' ' -> Just CycleCommand
        'e' -> Just EditTaskCommand
        'v' -> Just BackCommand
        '?' -> Just HelpCommand
        _ -> Nothing

helpCommand :: Char -> Maybe Command
helpCommand key =
    case key of
        '?' -> Just BackCommand
        _ -> Nothing

categoryCommand :: Char -> Maybe Command
categoryCommand key
    | isDigit key && key /= '0' =
        Just (SelectCategoryCommand (digitToInt key))
    | otherwise =
        case toLower key of
            'n' -> Just AddCategoryCommand
            'e' -> Just EditCategoryCommand
            'j' -> Just (MoveCategoryCommand Next)
            'k' -> Just (MoveCategoryCommand Previous)
            'w' -> Just (MoveCategoryCommand Previous)
            's' -> Just (MoveCategoryCommand Next)
            '?' -> Just HelpCommand
            _ -> Nothing
