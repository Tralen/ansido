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
import           Data.Char (digitToInt, isDigit, toLower)

import           Ansido.App.State (Direction (..), Screen (..))

-- | A decoded terminal key, with arrows separated from escape sequences.
data Key
  = KeyCharacter Char
  | KeyUp
  | KeyDown
  | KeyLeft
  | KeyRight
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
  | AddTaskCommand
  | AddCategoryCommand
  | CycleCommand Direction
  | DeleteCommand
  | MoveRowCommand Direction
  | SelectCategoryCommand Int
  deriving (Eq, Show)

-- | Resolves a key for the current screen.
commandForKey :: Screen -> Key -> Maybe Command
commandForKey screen key =
  case key of
    KeyEscape -> Just BackCommand
    KeyUp    -> boardOnly (MoveRowCommand Previous)
    KeyDown  -> boardOnly (MoveRowCommand Next)
    KeyLeft  -> Nothing
    KeyRight -> Nothing
    KeyEnter -> boardOnly (CycleCommand Next)
    KeyBackspace -> boardOnly (CycleCommand Previous)
    KeyCharacter char -> characterCommand screen char
  where
    boardOnly command =
      case screen of
        BoardScreen -> Just command
        _           -> Nothing

characterCommand :: Screen -> Char -> Maybe Command
characterCommand screen key =
  case key of
    'x' -> Just QuitCommand
    'X' -> Just QuitCommand
    'r' -> Just RedrawCommand
    'R' -> Just RedrawCommand
    _ ->
      case screen of
        BoardScreen      -> boardCommand (toLower key)
        HelpScreen       -> helpCommand (toLower key)
        CategoryScreen   -> categoryCommand key
        AddTaskScreen    -> Nothing
        AddCategoryScreen -> Nothing

boardCommand :: Char -> Maybe Command
boardCommand key =
  case key of
    'a' -> Just AddTaskCommand
    'c' -> Just CategoriesCommand
    'd' -> Just DeleteCommand
    'k' -> Just (MoveRowCommand Previous)
    'j' -> Just (MoveRowCommand Next)
    'b' -> Just BackCommand
    '?' -> Just HelpCommand
    _   -> Nothing

helpCommand :: Char -> Maybe Command
helpCommand key =
  case key of
    'b' -> Just BackCommand
    '?' -> Just BackCommand
    _   -> Nothing

categoryCommand :: Char -> Maybe Command
categoryCommand key
  | isDigit key && key /= '0' =
      Just (SelectCategoryCommand (digitToInt key))
  | otherwise =
      case toLower key of
        'n' -> Just AddCategoryCommand
        'b' -> Just BackCommand
        '?' -> Just HelpCommand
        _   -> Nothing
