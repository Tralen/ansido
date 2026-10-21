# Persistence

The application keeps its state in a plain text file, with no database or binary format.

## Location

The data file is resolved in this order:

1. The `ANSIDO_FILE` environment variable, when set and non-empty.
2. `$HOME/.ansido/board.tsv`.
3. If neither is available, `defaultDataFile` returns `FilePathUnavailable` and the application prints the reason.

`ANSIDO_FILE` is useful for tests and for keeping a separate board per project. The path is never hardcoded in the source.

## Format

The first line is the version header:

```
ansido	1
```

Each following line is a tab-separated record. Empty lines are ignored.

Category record:

```
category	<id>	<name>
```

Task record:

```
task	<id>	<category id>	<status>	<title>
```

`<status>` is one of `todo`, `doing` or `done`. Status labels shown on screen are uppercase, but the file always uses the stable lowercase keys.

Example:

```
ansido	1
category	1	Work
category	2	Personal
task	1	1	todo	Write the architecture document
task	2	1	doing	Implement the board
task	3	1	done	Create the project
task	4	2	todo	Buy coffee
```

## Parsing

`decodeWorkspace` is pure and returns `Either PersistenceError Workspace`. It checks the header, parses identifiers and status keys without using `read`, validates names and titles through the domain smart constructors and finally calls `mkWorkspace` to enforce referential integrity.

Failures are data:

| Error | Meaning |
| --- | --- |
| `UnsupportedHeader` | The first line is not the expected version header. |
| `MalformedLine` | A record has the wrong field count, an invalid identifier or an unknown status. |
| `InvalidWorkspace` | The records are well formed but violate a workspace invariant, such as a task pointing at a missing category. |

A missing file is treated as an empty workspace, not as an error. An empty file is also treated as an empty workspace.

## Writing

`saveWorkspace` writes to `<path>.tmp` and then renames it over the target. The rename is atomic on the same file system, so a crash during writing cannot leave a half-written board. The parent directory is created when needed.

File system exceptions are caught at the edge and converted to `ReadFailed` or `WriteFailed`. The application never throws from its own code.

## Compatibility

The format is versioned through the header. A future format should add a new header version and keep the decoder able to read version 1, or reject it explicitly with `UnsupportedHeader`.

## Manual editing

The file is intentionally readable and editable by hand. Keep one record per line, use tabs between fields, preserve unique identifiers and make sure every task points at an existing category. Invalid files are rejected with a line number instead of being partially loaded.
