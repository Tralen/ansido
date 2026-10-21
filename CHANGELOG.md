# Change Log

## Version History
*Major updates and feature releases.*

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

_None yet._
