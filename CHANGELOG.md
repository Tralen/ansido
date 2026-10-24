# Change Log

## Version History
*Major updates and feature releases.*

### 1.0.0
- Split the board footer into two solid bars: `Enter add`, `Space status`, `e edit`, `f filter` and `o sort` on the first, and `↑↓`, `Del del`, `? help`, `⌫ back` and `x exit` on the second.
- The create forms now use the Ansiform line editor with an empty initial buffer, so arrow keys, `Home`, `End` and `Delete` move the cursor instead of inserting control characters in both create and edit modes.
- Added a board sort that cycles with `o` through insertion order, status and title, shown on a `Sort:` line below the filter.
- Sorting is stable; title order ignores case, and every filter or sort change keeps the selected task selected while it remains visible.
- Changing a task status or editing a title now follows the selected task to its new position in a sorted table.
- Added `v` as a back key on the details screen, keeping `Backspace` and `Esc`.
- Added tests for the sort order, the sort and status selection handling and the new keys, and updated the create form prompt tests for the editable empty buffer.
- Changed the add-task footer hint from `empty cancel` to `empty title cancels`.
- Added a Fourmolu 0.21.0.0 configuration, a CI formatting gate and a local pre-commit hook, and formatted the Haskell sources.
- Documented SSH-signed commits and tags, including the signing configuration and verification steps.
- Prepared the project for the release checklist: manual GitHub and Hackage publication, checksum files and build provenance.
- Added a gitleaks history scan to CI and a pre-commit configuration for staged changes, using the pinned gitleaks action.
- Aligned CI with the release template: GHC 9.2.8 and 9.14.1 on Linux and macOS and GHC 9.14.1 on Windows, actions pinned by commit SHA, Cabal 3.18.1.0, dependency cache, `cabal check`, `cabal haddock` and `cabal sdist`.
- Documented the Windows/GHC 9.2.8 limitation caused by Ansiform's `hSize` dependency and removed the unused `release` environment reference from the GitHub release workflow.
- Corrected the package description, README data file path, Windows instructions, versioning policy and stale feature claims.
- Fixed stale comments and documentation around statuses, `reads`, Delete key decoding and startup errors.
- Added the 0.9.0 feature section to the correct CHANGELOG section.

### 0.9.0
- Raised Ansiform to 1.0 and adopted `promptWithInitial` in the edit forms.
- Edit task and edit category now open their prompts with the current title, note and name, so only the changed part has to be retyped.
- Empty input no longer means "keep current": an empty title or category name is rejected, while an empty task note clears the note.
- Replaced the edit hint `Empty input keeps the current value.` with `Edit the value and press Enter.`.
- Rewrote `docs/ansiform-form-defaults.md` to describe the implemented Ansiform API and its use in ansido.
- Added prompt tests for the initial values in the edit forms.

### 0.8.0
- Added arrow, `j`/`k` and `w`/`s` navigation to the category screen, so a category can be highlighted without opening its board.
- `Enter` now opens the board of the highlighted category.
- `e` and `Del` act on the highlighted category, which makes renaming and deletion visible from the category screen.
- Replaced the category footer digit hint with `Enter open`; the digits `1` to `9` still open a category directly.
- Added the GitHub homepage, issue tracker and source repository metadata to the package.
- Added tests for category navigation and the new category keys.

### 0.7.0
- Added category editing with the `e` key on the category screen; the form reuses the category prompt and keeps the current name when the input is empty.
- Added category deletion with the `Del` key; deleting a category also removes its tasks, and the notice reports how many tasks were removed.
- Removed the W/S hints from the board footer, leaving the arrow keys, and restored the `? help` hint.
- Changed the user-facing term `State` to `Status` in the board header, details fields, footer, notices and help.
- The `Press n to create a category.` hint is now shown only while there are no categories.
- Added tests for category editing, cascade deletion, category keys and the category form prompt positions.

### 0.6.0
- Added the `f` state filter on the board, cycling through all, Todo, Doing and Done.
- Added the `e` key to edit the selected task from the board and `f` to edit from the details view.
- The edit form reuses the task form, shows the current content above the prompts and keeps the current value when the input is empty.
- Removed the borders from the board, category and help tables.
- Added W/S as a third vertical navigation alternative, alongside the arrow keys and Vim keys.
- Moved task deletion to the `Del` key, including ANSI sequence decoding for the Delete key.
- Added a live filter line above the task table.
- Added tests for filtering, editing, the Delete key and W/S navigation.

### 0.5.0
- Updated Ansiform to 0.7.9.0 and adopted `readForm` for the task and category forms.
- Moved the help table one line up and added a blank line before the data file section.
- Styled the `Data file` label as bold yellow without italic.
- Moved the board notice directly below the table, with a blank line after it, so the table no longer shifts.
- Updated the Ansiform notes: group padding, forms, checked number arithmetic and solid-printer documentation are now covered by the library.
- Added a test for the task form prompt positions.

### 0.4.0
- Added a `v view` screen that shows the full task note with word wrap.
- Added the data file path to the help screen.
- Moved notices below the task table so the table does not shift when a notice appears.
- Removed the redundant `Categories` title; the category table now starts after the blank line.
- Changed the Todo state color from yellow to red.
- Changed the keys: `Enter` adds a task, `Space` cycles the selected task state and `Backspace` goes back.
- Removed the backward state cycle and the `a`, `b` and `c` shortcuts.
- Added tests for the details view, the data file path and the new key mapping.

### 0.3.0
- Replaced the three-column board with a single task table: title on the left, note as the main field and state in a small right column.
- Removed the task details screen; the note is now visible directly in the table.
- Navigation is vertical only, and `Enter` and `Backspace` cycle the selected task state forward and backward.
- Kept `j` and `k` as a Vim-style alternative for vertical navigation.
- Changed muted text to white italic, keeping the muted color only for horizontal rules.
- Added a blank line between the subtitle and the category tabs.
- The application now always starts on the category screen.
- Updated the author, maintainer and license metadata.
- Updated the tests for the table model, state cycling and the category start screen.

### 0.2.0
- Added a note field to every task, shown on the details screen and persisted with the task.
- Added a two-line prompt for the task title and task note.
- Added arrow key navigation for the board, with the Vim keys kept as an alternative.
- Moved the header rule below the category bar and added a blank line between the title bar and the subtitle.
- Board `b` now returns to the category selection, so `b` works again from the notes view.
- Upgraded the persistence format to version 2 and kept reading version 1 files.
- Added tests for task notes, version 1 compatibility, arrow keys and back navigation.

### 0.1.0
- Initial functional release of `ansido`.
- Added the domain model with categories, tasks, statuses and workspace invariants.
- Added pure transitions for creating categories and tasks, advancing and deleting tasks.
- Added plain text persistence with a versioned format, validation and atomic saving.
- Added the Ansiform board with Todo, Doing and Done columns, selection and windowing.
- Added task details, help and category screens.
- Added immediate input for navigation and line input for new tasks and categories.
- Added a shared theme and reusable header, footer, notice and truncation components.
- Added a pure test suite covering the domain, persistence, windowing and updates.

## Revision History
*Patches, bug fixes, and minor updates.*

### 0.8.2
- Made the data file portable: `ANSIDO_FILE` first, then `getHomeDirectory`, which works on Windows without `HOME`.
- Board files are now read and written as UTF-8 without newline translation; decoding also accepts CRLF files.
- `saveWorkspace` uses `renameFile`, which replaces an existing board on Windows through `MoveFileEx`.
- The executable sets the standard handles to UTF-8 so the interface renders on the Windows console.
- Added `.github/workflows/ci.yml`, building and testing on Linux, macOS and Windows.
- Documented the cross-platform behavior and the `j`/`k` and `w`/`s` fallback for terminals without ANSI arrow keys.
- Added a CRLF decode test.

### 0.8.1
- Moved the category notice directly below the category table, with a blank line before the footer, matching the board layout.
- Changed the README documentation and license links to absolute GitHub URLs so they also work on Hackage.

### 0.6.4
- Replaced the custom borderless row renderer with `printerTableBordered BordersNone` from Ansiform 0.7.10.3.
- The board, help and category tables keep their fixed widths, truncation and styles without column bands.
- Raised the Ansiform lower bound to 0.7.10.3.

### 0.6.3
- Added `docs/ansiform-form-defaults.md`, a design proposal for editable pre-filled form fields in Ansiform, including the current limitation, proposed `Prompt` API, line editor, compatibility and test plan.

### 0.6.2
- Removed the bracketed current value from the edit prompts; the current content remains above and empty input keeps the current value.
- Styled the `Categories:` label in the category bar with the bold yellow table-header style.

### 0.6.1
- Fixed the details view edit key: it is `e`, matching the board, not `f`.
- Moved the `Filter:` line one line up, directly below the rule, with a blank line below it.
- Styled the active filter name with the state color: Todo red, Doing cyan, Done green, and all bold white.
- Populated the edit prompt labels with the current title and note, truncated to 20 columns.
- Added key mapping checks for the board and details edit keys.
