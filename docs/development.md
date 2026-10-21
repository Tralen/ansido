# Development

## Requirements

- GHC 9.14.1, the version used for the current release.
- `cabal-install` 3.18 or newer.
- Ansiform 0.7.10.3 from Hackage.

## Commands

```sh
cabal update
cabal build all
cabal test all
cabal run ansido
```

Use a separate data file while developing:

```sh
ANSIDO_FILE=./scratch/board.tsv cabal run ansido
```

## Tests

The test suite is a small self-contained runner in `test/Main.hs`. It covers:

- Text validation and trimming, including task notes.
- Task and category transitions.
- Workspace invariants.
- Encode and decode round trips, version 1 compatibility, CRLF files and malformed inputs.
- Window slicing and borderless table construction with truncation.
- Arrow, Enter/Backspace/Space, Delete, W/S, edit/filter and back navigation key mapping.
- Category keys for creating, editing and deleting categories.
- Category navigation with arrows, `j`/`k`, `w`/`s` and the `Enter` board shortcut.
- Initial state on the category screen, vertical navigation, status cycling, filtering, editing, details, submit and select actions.
- Category editing, category deletion with its tasks and blank input keeping the current name.
- Data file path propagation through `withDataFile`.

The current suite has 43 tests.

A failing test prints its name and message and exits with a failure code. A passing run prints the number of tests.

## Cross-platform

The application targets Linux, macOS and Windows. GitHub Actions runs `cabal build all` and `cabal test all` on all three systems through `.github/workflows/ci.yml`.

The macOS job uses `macos-15` instead of `macos-latest`. The current `macos-latest` image ships the macOS 26/27 SDK, whose `arm64e.x1-macos` entries in the `.tbd` stub files are rejected by the linker that GHC 9.14.1 uses. Revisit the pin when a newer GHC links against that SDK.

- The data file uses `ANSIDO_FILE` or `getHomeDirectory`, never a hardcoded path. On Windows `getHomeDirectory` uses the profile directory, so `HOME` is optional.
- Board files are UTF-8 with Unix line endings on every platform. Reading also accepts CRLF files.
- `saveWorkspace` relies on `renameFile`, which already replaces an existing board on Windows.
- `app/Main.hs` sets the standard handles to UTF-8, so the arrows, the backspace icon and non-ASCII task text render on the Windows console.
- Arrow keys depend on the terminal sending ANSI escape sequences. Windows Terminal and modern consoles do; on a console that does not, use `j`/`k` or `w`/`s` for vertical navigation. Letter keys, Enter, Backspace, Space and Delete are decoded from plain characters and work everywhere.

## Versioning

The application follows semantic versioning. The version is single sourced from the `version` field in `ansido.cabal`. `Ansido.Version` reads it through the generated `Paths_ansido` module, so the interface never hardcodes a version string.

Bump rules:

- Patch for fixes and small refinements.
- Minor for new user-facing features or screens.
- Major for data model breaking changes or major milestones.

Every release is recorded in `CHANGELOG.md`, in the section that matches the size of the change. Commit messages start with the version.

## Adding a screen

1. Add a constructor to `Screen` in `Ansido.App.State`.
2. Add the rendering branch in `Ansido.Ui.Page.screenBody` and the footer hints in `footerHints`.
3. Add an `Action` when the screen changes the state, and handle it in `Ansido.App.Update.update`.
4. Map the relevant keys in `Ansido.App.Command.commandForKey`, including arrows when the screen supports them.
5. Thread any new input through `Ansido.App.Run`, using `readForm` with prompts built from the page sections instead of counting lines.
6. Add tests for the pure update and any new pure helper.
7. Document the screen and keys in `docs/interface.md`.

## Adding a dependency

Keep the dependency footprint small. The application currently uses `base`, `ansiform`, `directory` and `filepath`. Arrow decoding uses `System.Timeout`, which is part of `base`. Persistence is deliberately plain text, so a database or serialization library is not needed. Justify any new dependency in the change summary and in this document.

## Code rules

- No reassignment or mutation after creation.
- No `for` or `while`; use `map`, `filter`, `foldr` and recursion.
- No `throw` or `panic` in application code; use `Either` and closed error types.
- No `any` or `unknown` equivalents; model states with algebraic data types.
- Use newtypes for identifiers and validated text.
- Code, comments and file names are in English.
- Comments end with a period.

## Cabal notes

`cabal-version: 2.4` is the version of the `.cabal` file specification, not the version of the installed `cabal-install` tool. The tool is 3.18, but the package file uses the 2.4 specification because the project needs only features available there and this keeps the file readable by older toolchains. The `cabal-version` field should be raised only when the file starts using a newer specification feature.

`Paths_ansido` is listed in both `autogen-modules` and `other-modules`, because Cabal 3.18 rejects an autogenerated module that is not exposed or listed as an internal module. The Ansiform umbrella module exports `renderPage`; the application hides that name in the modules that define their own `renderPage`.
