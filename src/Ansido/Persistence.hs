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
import Control.Exception (IOException, evaluate, try)
import Data.Maybe (catMaybes)
import Numeric.Natural (Natural)
import System.Directory
    ( createDirectoryIfMissing
    , doesFileExist
    , getHomeDirectory
    , renameFile
    )
import System.Environment (lookupEnv)
import System.FilePath (takeDirectory, (</>))
import System.IO
    ( IOMode (ReadMode, WriteMode)
    , hGetContents
    , hPutStr
    , hSetEncoding
    , hSetNewlineMode
    , noNewlineTranslation
    , utf8
    , withFile
    )
import Text.Read (readMaybe)

import Ansido.Domain

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
formatHeader = headerFor 2

headerFor :: Int -> String
headerFor version = "ansido\t" <> show version

headerVersion :: String -> Maybe Int
headerVersion header =
    lookup header [(headerFor 1, 1), (headerFor 2, 2)]

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
        , taskContentText (taskContent task)
        ]

joinTabs :: [String] -> String
joinTabs values =
    case values of
        [] -> ""
        (v : vs) -> foldl (\acc next -> acc <> "\t" <> next) v vs

-- | Parses the plain text format into a workspace.
--
-- Carriage returns are removed first, so files written or copied on Windows
-- still parse on every platform.
decodeWorkspace :: String -> Either PersistenceError Workspace
decodeWorkspace raw =
    case lines (filter (/= '\r') raw) of
        [] -> Right emptyWorkspace
        (header : body) ->
            case headerVersion header of
                Nothing -> Left (UnsupportedHeader header)
                Just version -> decodeEntries version body

decodeEntries :: Int -> [String] -> Either PersistenceError Workspace
decodeEntries version body = do
    entries <- traverse decodeAt (zip [2 ..] body)
    let records = catMaybes entries
        categories = [category | Left category <- records]
        tasks = [task | Right task <- records]
    case mkWorkspace categories tasks of
        Left domainError -> Left (InvalidWorkspace domainError)
        Right workspace -> Right workspace
  where
    decodeAt (lineNumber, line)
        | null line = Right Nothing
        | otherwise = Just <$> decodeLine version lineNumber line

decodeLine ::
    Int ->
    Int ->
    String ->
    Either PersistenceError (Either Category Task)
decodeLine version lineNumber line =
    case (version, splitTabs line) of
        (_, ["category", idText, nameText]) -> do
            identifier <- parseCategoryId lineNumber idText
            name <- parseCategoryName lineNumber nameText
            Right (Left (mkCategory identifier name))
        (1, ["task", idText, categoryText, statusText, titleText]) ->
            decodeTask lineNumber idText categoryText statusText titleText ""
        (2, ["task", idText, categoryText, statusText, titleText, contentText]) ->
            decodeTask lineNumber idText categoryText statusText titleText contentText
        _ -> Left (MalformedLine lineNumber "Expected a category or task record.")

decodeTask ::
    Int ->
    String ->
    String ->
    String ->
    String ->
    String ->
    Either PersistenceError (Either Category Task)
decodeTask lineNumber idText categoryText statusText titleText contentText = do
    identifier <- parseTaskId lineNumber idText
    categoryIdentifier <- parseCategoryId lineNumber categoryText
    status <- parseStatus lineNumber statusText
    title <- parseTaskTitle lineNumber titleText
    content <- parseTaskContent lineNumber contentText
    Right (Right (mkTask identifier title content status categoryIdentifier))

splitTabs :: String -> [String]
splitTabs value =
    case break (== '\t') value of
        (field, []) -> [field]
        (field, _ : rest) -> field : splitTabs rest

parseCategoryId :: Int -> String -> Either PersistenceError CategoryId
parseCategoryId lineNumber text =
    case readNatural text of
        Nothing ->
            Left (MalformedLine lineNumber ("Invalid category id: " <> text))
        Just value ->
            case mkCategoryId value of
                Left domainError ->
                    Left
                        ( MalformedLine
                            lineNumber
                            (domainErrorMessage domainError)
                        )
                Right identifier -> Right identifier

parseTaskId :: Int -> String -> Either PersistenceError TaskId
parseTaskId lineNumber text =
    case readNatural text of
        Nothing ->
            Left (MalformedLine lineNumber ("Invalid task id: " <> text))
        Just value ->
            case mkTaskId value of
                Left domainError ->
                    Left
                        ( MalformedLine
                            lineNumber
                            (domainErrorMessage domainError)
                        )
                Right identifier -> Right identifier

parseCategoryName :: Int -> String -> Either PersistenceError CategoryName
parseCategoryName lineNumber text =
    case mkCategoryName text of
        Left domainError -> Left (MalformedLine lineNumber (domainErrorMessage domainError))
        Right name -> Right name

parseTaskTitle :: Int -> String -> Either PersistenceError TaskTitle
parseTaskTitle lineNumber text =
    case mkTaskTitle text of
        Left domainError -> Left (MalformedLine lineNumber (domainErrorMessage domainError))
        Right title -> Right title

parseTaskContent :: Int -> String -> Either PersistenceError TaskContent
parseTaskContent lineNumber text =
    case mkTaskContent text of
        Left domainError -> Left (MalformedLine lineNumber (domainErrorMessage domainError))
        Right content -> Right content

parseStatus :: Int -> String -> Either PersistenceError Status
parseStatus lineNumber text =
    case statusFromKey text of
        Just status -> Right status
        Nothing -> Left (MalformedLine lineNumber ("Unknown status: " <> text))

readNatural :: String -> Maybe Natural
readNatural = readMaybe

-- File access.
--------------------------------------------------------------------------------

-- | Resolves the data file, honouring @ANSIDO_FILE@ and falling back to the
-- user home directory with @.ansido/board.tsv@.
--
-- 'getHomeDirectory' reads @HOME@ on Unix and the platform profile directory on
-- Windows, so the same code works on every system.
defaultDataFile :: IO (Either PersistenceError FilePath)
defaultDataFile = do
    override <- lookupEnv "ANSIDO_FILE"
    case override of
        Just path | not (null path) -> pure (Right path)
        _ -> do
            homeResult <- tryIO getHomeDirectory
            pure $ case homeResult of
                Right directory
                    | not (null directory) ->
                        Right (directory </> ".ansido" </> "board.tsv")
                _ ->
                    Left
                        ( FilePathUnavailable
                            "Set ANSIDO_FILE or a home directory to choose a data file."
                        )

-- | Loads the data file, treating a missing file as an empty workspace.
loadWorkspace :: FilePath -> IO (Either PersistenceError Workspace)
loadWorkspace path = do
    existsResult <- tryIO (doesFileExist path)
    case existsResult of
        Left exception -> pure (Left (ReadFailed path (show exception)))
        Right False -> pure (Right emptyWorkspace)
        Right True -> do
            result <- tryIO (readTextFile path)
            pure $ case result of
                Left exception -> Left (ReadFailed path (show exception))
                Right fileContent -> decodeWorkspace fileContent

-- | Saves the data file atomically through a temporary sibling file.
--
-- 'renameFile' replaces an existing destination on every supported platform.
-- It is atomic on POSIX and uses @MoveFileEx@ with @MOVEFILE_REPLACE_EXISTING@
-- on Windows.
saveWorkspace :: FilePath -> Workspace -> IO (Either PersistenceError ())
saveWorkspace path workspace = do
    let directory = takeDirectory path
    directoryResult <- tryIO (createDirectoryIfMissing True directory)
    case directoryResult of
        Left exception -> pure (Left (WriteFailed path (show exception)))
        Right () -> do
            let temporary = path <> ".tmp"
            writeResult <- tryIO (writeTextFile temporary (encodeWorkspace workspace))
            case writeResult of
                Left exception -> pure (Left (WriteFailed path (show exception)))
                Right () -> do
                    renameResult <- tryIO (renameFile temporary path)
                    pure $ case renameResult of
                        Left exception -> Left (WriteFailed path (show exception))
                        Right () -> Right ()

-- | Reads a UTF-8 file without newline translation.
--
-- The whole content is forced before the handle closes, so the result does not
-- depend on lazy IO and the format stays identical on every platform.
readTextFile :: FilePath -> IO String
readTextFile path =
    withFile path ReadMode $ \handle -> do
        hSetEncoding handle utf8
        hSetNewlineMode handle noNewlineTranslation
        contents <- hGetContents handle
        _ <- evaluate (length contents)
        pure contents

-- | Writes a UTF-8 file without newline translation.
writeTextFile :: FilePath -> String -> IO ()
writeTextFile path contents =
    withFile path WriteMode $ \handle -> do
        hSetEncoding handle utf8
        hSetNewlineMode handle noNewlineTranslation
        hPutStr handle contents

tryIO :: IO a -> IO (Either IOException a)
tryIO = try
