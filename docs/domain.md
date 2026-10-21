# Domain

The domain module defines the vocabulary of the application and the only legal transitions.

## Entities

| Type | Purpose |
| --- | --- |
| `CategoryId` | Newtype over `Int`, stable identifier of a category. |
| `CategoryName` | Newtype over `String`, validated category name. |
| `TaskId` | Newtype over `Int`, stable identifier of a task. |
| `TaskTitle` | Newtype over `String`, validated task title. |
| `TaskContent` | Newtype over `String`, validated task note. It may be empty. |
| `Category` | Identifier and validated name. |
| `Task` | Identifier, title, note, status and owning category. |
| `Status` | `Todo`, `Doing` or `Done`. |
| `Workspace` | Ordered categories and ordered tasks. |

`Workspace` hides its constructor. Values are built by `mkWorkspace`, `emptyWorkspace`, `addCategory`, `addTask`, `moveTask`, `advanceTask` and `deleteTask`.

## Validation

`mkCategoryName`, `mkTaskTitle` and `mkTaskContent` trim surrounding whitespace and then check three rules:

1. The result cannot be empty, except for a task note.
2. The text cannot contain control characters, including tabs and newlines.
3. The text cannot exceed its limit. The limits are 40 characters for a category name, 120 for a task title and 500 for a task note.

Control characters are rejected because the persistence format is line and tab based. This keeps every title, name and note on a single record field. An empty task note is valid and is shown as `(empty)` in the note column.

## Workspace invariants

`mkWorkspace` enforces:

- Category identifiers are unique.
- Category names are unique.
- Task identifiers are unique.
- Every task points at an existing category.

A broken invariant becomes `DuplicateCategoryId`, `DuplicateCategoryName`, `DuplicateTaskId` or `UnknownCategory`.

## Transitions

| Function | Result |
| --- | --- |
| `addCategory name workspace` | The new `Category` and the new `Workspace`. |
| `addTask category title content workspace` | The new `Task` and the new `Workspace`. New tasks start at `Todo`. |
| `moveTask identifier status workspace` | A workspace with the task status replaced. |
| `advanceTask identifier workspace` | A workspace with the task moved along the status cycle. |
| `deleteTask identifier workspace` | A workspace without the task. |

All transitions return `Either DomainError a`. None of them throw.

## Identifiers

Identifiers are allocated from the current maximum plus one. Deleting the newest task or category can therefore free its identifier for reuse, which is acceptable because the application has no external references to identifiers.

## Status cycle

The `Space` key follows `Todo -> Doing -> Done -> Todo` through `nextStatus`. The application applies it with `moveTask`, so the transition stays pure and the task keeps its position in the table.

Status labels are displayed in title case as `Todo`, `Doing` and `Done`, while the persistence format keeps the lowercase keys `todo`, `doing` and `done`.

## Queries

`categoryTasks`, `tasksByStatus`, `taskCount`, `findCategory`, `findTask` and `indexMaybe` are pure queries. `indexMaybe` replaces the partial `!!` operator, so selection code never crashes on an out-of-range index.

## Errors

`DomainError` is a closed algebraic data type. `domainErrorMessage` is the only place where a domain failure becomes text, which keeps messages consistent across the board, notices and the persistence parser.
