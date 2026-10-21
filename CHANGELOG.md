# Change Log

## Version History
*Major updates and feature releases.*

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

### 0.6.1
- Fixed the details view edit key: it is `e`, matching the board, not `f`.
- Moved the `Filter:` line one line up, directly below the rule, with a blank line below it.
- Styled the active filter name with the state color: Todo red, Doing cyan, Done green, and all bold white.
- Populated the edit prompt labels with the current title and note, truncated to 20 columns.
- Added key mapping checks for the board and details edit keys.
