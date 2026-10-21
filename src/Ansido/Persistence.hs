-- | Plain text persistence with errors as data.
--
-- The format is line based and tab separated, with a versioned header. File
-- IO happens only in 'loadWorkspace' and 'saveWorkspace'; parsing and
-- rendering are pure and testable.
module Ansido.Persistence
  ( PersistenceError (..)
  , persistenceErrorMessage
  , encodeWorkspace
  , decodeWorkspace
  , defaultDataFile
  , loadWorkspace
  , saveWorkspace
  ) where

--------------------------------------------------------------------------------
import           Control.Exception (IOException, try)
import           Data.Maybe (catMaybes)
import           System.Directory (createDirectoryIfMissing, doesFileExist,
                                   renameFile)
import           System.Environment (lookupEnv)
import           System.FilePath (takeDirectory, (</>))

import           Ansido.Domain

-- Errors.
--------------------------------------------------------------------------------

-- | Everything that can go wrong while reading or writing the data file.
data PersistenceError
  = ReadFailed FilePath String
  | WriteFailed FilePath String
  | FilePathUnavailable String
  | UnsupportedHeader String
  | MalformedLine Int String
  | InvalidWorkspace DomainError
  deriving (Eq, Show)

-- | English message for a persistence error.
persistenceErrorMessage :: PersistenceError -> String
persistenceErrorMessage err =
  case err of
    ReadFailed path reason ->
      "Could not read " <> path <> ": " <> reason
    WriteFailed path reason ->
      "Could not write " <> path <> ": " <> reason
    FilePathUnavailable reason -> reason
    UnsupportedHeader header ->
      "Unsupported file header: " <> header
    MalformedLine lineNumber reason ->
      "Malformed line " <> show lineNumber <> ": " <> reason
    InvalidWorkspace domainError -> domainErrorMessage domainError

-- Format.
--------------------------------------------------------------------------------

formatHeader :: String
formatHeader = "ansido\t1"

-- | Renders a workspace into the plain text format.
encodeWorkspace :: Workspace -> String
encodeWorkspace workspace =
  unlines
    ( formatHeader
        : map encodeCategory (workspaceCategories workspace)
        <> map encodeTask (workspaceTasks workspace)
    )

encodeCategory :: Category -> String
encodeCategory category =
  joinTabs
    [ "category"
    , show (categoryIdValue (categoryId category))
    , categoryNameText (categoryName category)
    ]

encodeTask :: Task -> String
encodeTask task =
  joinTabs
    [ "task"
    , show (taskIdValue (taskId task))
    , show (categoryIdValue (taskCategory task))
    , statusKey (taskStatus task)
    , taskTitleText (taskTitle task)
    ]

joinTabs :: [String] -> String
joinTabs values =
  case values of
    []       -> ""
    (v : vs) -> foldl (\acc next -> acc <> "\t" <> next) v vs

-- | Parses the plain text format into a workspace.
decodeWorkspace :: String -> Either PersistenceError Workspace
decodeWorkspace raw =
  case lines raw of
    [] -> Right emptyWorkspace
    (header : body)
      | header /= formatHeader -> Left (UnsupportedHeader header)
      | otherwise -> do
          entries <- traverse decodeAt (zip [2 ..] body)
          let records = catMaybes entries
              categories = [category | Left category <- records]
              tasks = [task | Right task <- records]
          case mkWorkspace categories tasks of
            Left domainError -> Left (InvalidWorkspace domainError)
            Right workspace  -> Right workspace
  where
    decodeAt (lineNumber, line)
      | null line = Right Nothing
      | otherwise = Just <$> decodeLine lineNumber line

decodeLine :: Int -> String -> Either PersistenceError (Either Category Task)
decodeLine lineNumber line =
  case splitTabs line of
    ["category", idText, nameText] -> do
      identifier <- parseCategoryId lineNumber idText
      name <- parseCategoryName lineNumber nameText
      Right (Left (Category identifier name))
    ["task", idText, categoryText, statusText, titleText] -> do
      identifier <- parseTaskId lineNumber idText
      categoryIdentifier <- parseCategoryId lineNumber categoryText
      status <- parseStatus lineNumber statusText
      title <- parseTaskTitle lineNumber titleText
      Right (Right (Task identifier title status categoryIdentifier))
    _ -> Left (MalformedLine lineNumber "Expected a category or task record.")

splitTabs :: String -> [String]
splitTabs value =
  case break (== '\t') value of
    (field, [])     -> [field]
    (field, _ : rest) -> field : splitTabs rest

parseCategoryId :: Int -> String -> Either PersistenceError CategoryId
parseCategoryId lineNumber text =
  case readInt text of
    Just value | value > 0 -> Right (CategoryId value)
    _ -> Left (MalformedLine lineNumber ("Invalid category id: " <> text))

parseTaskId :: Int -> String -> Either PersistenceError TaskId
parseTaskId lineNumber text =
  case readInt text of
    Just value | value > 0 -> Right (TaskId value)
    _ -> Left (MalformedLine lineNumber ("Invalid task id: " <> text))

parseCategoryName :: Int -> String -> Either PersistenceError CategoryName
parseCategoryName lineNumber text =
  case mkCategoryName text of
    Left domainError -> Left (MalformedLine lineNumber (domainErrorMessage domainError))
    Right name       -> Right name

parseTaskTitle :: Int -> String -> Either PersistenceError TaskTitle
parseTaskTitle lineNumber text =
  case mkTaskTitle text of
    Left domainError -> Left (MalformedLine lineNumber (domainErrorMessage domainError))
    Right title      -> Right title

parseStatus :: Int -> String -> Either PersistenceError Status
parseStatus lineNumber text =
  case statusFromKey text of
    Just status -> Right status
    Nothing     -> Left (MalformedLine lineNumber ("Unknown status: " <> text))

readInt :: String -> Maybe Int
readInt text =
  case reads text of
    [(value, "")] -> Just value
    _             -> Nothing

-- File access.
--------------------------------------------------------------------------------

-- | Resolves the data file, honouring @ANSIDO_FILE@ and falling back to
-- @$HOME/.ansido/board.tsv@.
defaultDataFile :: IO (Either PersistenceError FilePath)
defaultDataFile = do
  override <- lookupEnv "ANSIDO_FILE"
  case override of
    Just path | not (null path) -> pure (Right path)
    _ -> do
      home <- lookupEnv "HOME"
      pure $ case home of
        Just directory | not (null directory) ->
          Right (directory </> ".ansido" </> "board.tsv")
        _ -> Left (FilePathUnavailable "Set HOME or ANSIDO_FILE to choose a data file.")

-- | Loads the data file, treating a missing file as an empty workspace.
loadWorkspace :: FilePath -> IO (Either PersistenceError Workspace)
loadWorkspace path = do
  exists <- doesFileExist path
  if not exists
    then pure (Right emptyWorkspace)
    else do
      result <- tryIO (readFile path)
      pure $ case result of
        Left exception     -> Left (ReadFailed path (show exception))
        Right fileContent -> decodeWorkspace fileContent

-- | Saves the data file atomically through a temporary sibling file.
saveWorkspace :: FilePath -> Workspace -> IO (Either PersistenceError ())
saveWorkspace path workspace = do
  let directory = takeDirectory path
  directoryResult <- tryIO (createDirectoryIfMissing True directory)
  case directoryResult of
    Left exception -> pure (Left (WriteFailed path (show exception)))
    Right () -> do
      let temporary = path <> ".tmp"
      writeResult <- tryIO (writeFile temporary (encodeWorkspace workspace))
      case writeResult of
        Left exception -> pure (Left (WriteFailed path (show exception)))
        Right () -> do
          renameResult <- tryIO (renameFile temporary path)
          pure $ case renameResult of
            Left exception -> Left (WriteFailed path (show exception))
            Right ()     -> Right ()

tryIO :: IO a -> IO (Either IOException a)
tryIO = try
