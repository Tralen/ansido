# Domain

The domain module defines the vocabulary of the application and the only legal transitions.

## Entities

| Type | Purpose |
| --- | --- |
| `CategoryId` | Newtype over positive `Natural`, stable identifier of a category. |
| `CategoryName` | Newtype over `String`, validated category name. |
| `TaskId` | Newtype over positive `Natural`, stable identifier of a task. |
| `TaskTitle` | Newtype over `String`, validated task title. |
| `TaskContent` | Newtype over `String`, validated task note. It may be empty. |
| `Category` | Identifier and validated name. |
| `Task` | Identifier, title, note, status and owning category. |
| `Status` | `Todo`, `Doing` or `Done`. |
| `Workspace` | Ordered categories and ordered tasks. |

`Workspace` hides its constructor. Values are built by `mkWorkspace`, `emptyWorkspace`, `addCategory`, `editCategory`, `deleteCategory`, `addTask`, `moveTask`, `advanceTask`, `editTask` and `deleteTask`.

The constructors of `CategoryId`, `TaskId`, `Category`, `Task`, `CategoryName`, `TaskTitle` and `TaskContent` are hidden. `mkCategoryId` and `mkTaskId` reject zero, `mkCategoryName`, `mkTaskTitle` and `mkTaskContent` validate the text, and `mkCategory` and `mkTask` build an entity only from already validated parts. `Status (..)` stays public because it is a closed enumeration. The `Category` and `Task` fields are strict, so the validated values are forced as the records are built.

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
| `editCategory identifier name workspace` | A workspace with the category renamed. The new name must not belong to another category. |
| `deleteCategory identifier workspace` | A workspace without the category and without every task it owned. |
| `addTask category title content workspace` | The new `Task` and the new `Workspace`. New tasks start at `Todo`. |
| `moveTask identifier status workspace` | A workspace with the task status replaced. |
| `advanceTask identifier workspace` | A workspace with the task moved along the status cycle. |
| `editTask identifier title content workspace` | A workspace with the task title and note replaced. |
| `deleteTask identifier workspace` | A workspace without the task. |

All transitions return `Either DomainError a`. None of them throw. Deleting a category is a cascade: its tasks have no other owner, so they are removed with it. The application reports how many tasks were removed in the notice shown after the deletion.

## Identifiers

Identifiers are positive `Natural` values. `mkCategoryId` and `mkTaskId` reject zero, and the internal allocators take the current maximum plus one. Deleting the newest task or category can therefore free its identifier for reuse, which is acceptable because the application has no external references to identifiers.

## Status cycle

The `Space` key follows `Todo -> Doing -> Done -> Todo` through `nextStatus`. The application applies it with `moveTask`, so the transition stays pure. Under the original order the task keeps its position in the table; under a sort the selection follows the task to its new position.

Status labels are displayed in title case as `Todo`, `Doing` and `Done`, while the persistence format keeps the lowercase keys `todo`, `doing` and `done`.

## Queries

`categoryTasks`, `tasksByStatus`, `taskCount`, `findCategory`, `findTask` and `indexMaybe` are pure queries. `indexMaybe` replaces the partial `!!` operator, so selection code never crashes on an out-of-range index.

## Errors

`DomainError` is a closed algebraic data type. `InvalidCategoryId` and `InvalidTaskId` report a zero identifier, while the other constructors cover text validation, unknown entities and workspace invariants. `domainErrorMessage` is the only place where a domain failure becomes text, which keeps messages consistent across the board, notices and the persistence parser.
