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
import           Ansido.Domain (Status (..))

-- | A decoded terminal key, with arrows separated from escape sequences.
data Key
  = KeyCharacter Char
  | KeyUp
  | KeyDown
  | KeyLeft
  | KeyRight
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
  | AddTaskCommand
  | AddCategoryCommand
  | AdvanceCommand
  | DeleteCommand
  | MoveColumnCommand Direction
  | MoveRowCommand Direction
  | FocusStatusCommand Status
  | SelectCategoryCommand Int
  deriving (Eq, Show)

-- | Resolves a key for the current screen.
commandForKey :: Screen -> Key -> Maybe Command
commandForKey screen key =
  case key of
    KeyEscape -> Just BackCommand
    KeyUp    -> boardOnly (MoveRowCommand Previous)
    KeyDown  -> boardOnly (MoveRowCommand Next)
    KeyLeft  -> boardOnly (MoveColumnCommand Previous)
    KeyRight -> boardOnly (MoveColumnCommand Next)
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
        DetailsScreen _  -> detailsCommand (toLower key)
        HelpScreen       -> helpCommand (toLower key)
        CategoryScreen   -> categoryCommand key
        AddTaskScreen    -> Nothing
        AddCategoryScreen -> Nothing

boardCommand :: Char -> Maybe Command
boardCommand key =
  case key of
    'a' -> Just AddTaskCommand
    'c' -> Just CategoriesCommand
    'v' -> Just DetailsCommand
    'm' -> Just AdvanceCommand
    'd' -> Just DeleteCommand
    'h' -> Just (MoveColumnCommand Previous)
    'l' -> Just (MoveColumnCommand Next)
    'k' -> Just (MoveRowCommand Previous)
    'j' -> Just (MoveRowCommand Next)
    '1' -> Just (FocusStatusCommand Todo)
    '2' -> Just (FocusStatusCommand Doing)
    '3' -> Just (FocusStatusCommand Done)
    'b' -> Just BackCommand
    '?' -> Just HelpCommand
    _   -> Nothing

detailsCommand :: Char -> Maybe Command
detailsCommand key =
  case key of
    'b' -> Just BackCommand
    'm' -> Just AdvanceCommand
    'd' -> Just DeleteCommand
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
  | isDigit key && key /= '0' = Just (SelectCategoryCommand (digitToInt key))
  | otherwise =
      case toLower key of
        'n' -> Just AddCategoryCommand
        'b' -> Just BackCommand
        '?' -> Just HelpCommand
        _   -> Nothing
