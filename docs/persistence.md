# Persistence

The application keeps its state in a plain text file, with no database or binary format.

## Location

The data file is resolved in this order:

1. The `ANSIDO_FILE` environment variable, when set and non-empty.
2. `<home>/.ansido/board.tsv`, where `<home>` comes from `getHomeDirectory`. On Unix this reads `HOME`; on Windows it uses the platform profile directory, so `HOME` does not need to be set.
3. If neither is available, `defaultDataFile` returns `FilePathUnavailable` and the application prints the reason.

`ANSIDO_FILE` is useful for tests and for keeping a separate board per project. The path is never hardcoded in the source.

## Format

The current format is version 2. The first line is the version header:

```
ansido	2
```

Each following line is a tab-separated record. Empty lines are ignored.

Category record:

```
category	<id>	<name>
```

Task record:

```
task	<id>	<category id>	<status>	<title>	<note>
```

`<status>` is one of `todo`, `doing` or `done`. Status labels shown on screen are title case, but the file always uses the stable lowercase keys. `<note>` may be empty; the field is still written, so the line ends with a tab when the note is empty. Identifiers are positive integers.

Example:

```
ansido	2
category	1	Work
category	2	Personal
task	1	1	todo	Write the architecture document	Remember the pure core section.
task	2	1	doing	Implement the board	Use groups and borders.
task	3	1	done	Create the project	Initial commit.
task	4	2	todo	Buy coffee	Personal errand.
```

## Parsing

`decodeWorkspace` is pure and returns `Either PersistenceError Workspace`. It checks the header, parses identifiers with `readMaybe` as positive `Natural` values, parses status keys, validates names, titles and notes through the domain smart constructors and finally calls `mkWorkspace` to enforce referential integrity. Carriage returns are removed before splitting the lines, so files written or copied on Windows parse the same way on every platform.

Version 1 files are still accepted. A version 1 task has no note field, so its note becomes empty. Version 2 files require the note field, even when it is empty.

Failures are data:

| Error | Meaning |
| --- | --- |
| `UnsupportedHeader` | The first line is not the version 1 or version 2 header. |
| `MalformedLine` | A record has the wrong field count, an invalid identifier or an unknown status. |
| `InvalidWorkspace` | The records are well formed but violate a workspace invariant, such as a task pointing at a missing category. |

A missing file is treated as an empty workspace, not as an error. An empty file is also treated as an empty workspace.

## Writing

`saveWorkspace` writes to `<path>.tmp` and then renames it over the target. `renameFile` replaces an existing destination on every supported platform and is atomic on POSIX; on Windows it uses `MoveFileEx` with `MOVEFILE_REPLACE_EXISTING`. The parent directory is created when needed.

Files are read and written as UTF-8 and newline translation is disabled, so the board keeps Unix line endings and non-ASCII text on every platform. File system exceptions are caught at the edge and converted to `ReadFailed` or `WriteFailed`. The application does not throw for domain or input errors; a startup failure prints a message and exits with a failure code.

## Compatibility

The format is versioned through the header. The current release writes version 2 and reads both version 1 and version 2. A future format should add a new header version and keep the decoder able to read the previous versions, or reject them explicitly with `UnsupportedHeader`.

## Manual editing

The file is intentionally readable and editable by hand. Keep one record per line, use tabs between fields, preserve unique identifiers and make sure every task points at an existing category. For a version 2 task, keep the trailing tab when the note is empty. Invalid files are rejected with a line number instead of being partially loaded.
