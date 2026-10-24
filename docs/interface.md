# Interface

The interface is built with Ansiform pages, sections, borderless tables, forms and immediate input.

## Screens

| Screen | Purpose |
| --- | --- |
| Categories | Category list with task counts, highlighting and navigation. This is always the initial screen. |
| Board | Task table with title, note and status for the selected category, with a live status filter and sort order. |
| Details | Full task view with the complete note wrapped across lines. |
| Edit task | Task form with the current content above the prompts. |
| Help | Key reference in a borderless table, followed by the data file path. |
| Add task | Task table preview with title and note prompts at the bottom. |
| Add category | Category preview with a name prompt at the bottom. |
| Edit category | Category form with the current name and task count above the prompt. |

Every screen shares the same header, category bar and footer. The header shows the application name and version. The category bar always shows all categories, with the active one highlighted. The footer lists the shortcuts available on the current screen.

## Keys

### Board

| Key | Action |
| --- | --- |
| `↑` / `↓` | Select the previous or next task. |
| `j` / `k` | Vim-style alternative to the vertical arrow keys. |
| `w` / `s` | WASD-style alternative to the vertical arrow keys. |
| `Enter` | Open the new task prompt. |
| `Space` | Cycle the selected task status forward. |
| `e` | Edit the selected task. |
| `f` | Cycle the status filter. |
| `o` | Cycle the sort order. |
| `Del` | Delete the selected task. |
| `v` | Open the full task view. |
| `Backspace` or `Esc` | Go back to the category selection. |
| `?` | Open help. |
| `r` | Redraw the current page. |
| `x` | Exit. |

The status cycle is `Todo -> Doing -> Done -> Todo`. Under the original order the selected row keeps its place because the table keeps insertion order; under a sort it follows the task to the new position.

The footer shows the arrow keys without a label, followed by `Enter add`, `Space status`, `e edit`, `f filter`, `o sort`, `Del del`, `? help`, the back icon and `x exit`. The `w` and `s` keys still work, but they are documented here and on the help screen instead of the footer.

### Details

`Backspace`, `Esc` or `v` returns to the board, `Space` cycles the task status, `e` edits the task, `Del` deletes it, `?` opens help and `x` exits. The complete note is shown with word wrap.

### Edit task

The edit screen reuses the task form and shows the current title, status, category and note above the prompts. The title and note prompts open with the current values, so only the part that needs to change has to be edited. Enter submits after the note prompt, and the board returns with a confirmation notice. An empty title is rejected; an empty note clears the note.

Ansiform 1.0 provides the line editor behind `promptWithInitial`, so the current value is an editable buffer instead of a hint above an empty field.

### Categories

`↑` and `↓`, `j` and `k`, or `w` and `s` move the highlighted category without leaving the screen. `Enter` opens the board of the highlighted category, `1` to `9` open a category directly, `n` opens the new category prompt, `e` renames the highlighted category, `Del` deletes it together with its tasks, `Backspace` or `Esc` returns to the board and `x` exits.

The hint `Press n to create a category.` is shown below the category table only while there are no categories. The category footer lists the arrow keys, `Enter open`, `n new`, `e edit`, `Del del`, the back icon and `x exit`.

The category notice sits directly below the table, or below the creation hint when the workspace is empty, and a blank line separates it from the footer. This matches the board notice position.

Moving the highlight resets the task row so the next board opens on its first task. The category bar and the table row highlight the same category.

### Edit category

The edit screen reuses the category form and shows the current name and task count above the prompt. The name prompt opens with the current name. Enter submits the value and the category screen returns with a confirmation notice. An empty name is rejected.

### Help

`Backspace`, `?` or `Esc` returns to the board. `x` exits.

### Back navigation

The back key follows the screen hierarchy: details and task edit return to the board, category edit returns to the category selection, the board returns to the category selection, the category selection returns to the board and help returns to the board. `Backspace` is the primary back key, `Esc` is an alternative, and `v` also returns from the details view.

### Prompts

The create form has two lines: the title and the note. Type the title, press `Enter`, type the note and press `Enter` again. An empty title cancels the create prompt. An empty note is valid and creates a task with `(empty)` in the note column. The category prompt has a single line. Empty category input cancels and returns to the category selection. Every form opens its prompts in the Ansiform line editor, which supports moving, deleting and inserting inside the text; edit forms start with the current value and show the hint line `Edit the value and press Enter.`. Clearing the title or category name is rejected, and clearing the task note removes it.

Input is validated by the domain smart constructors, so an overlong title, an overlong note or a text with control characters becomes a notice instead of a broken record.

## Filtering and sorting

The `f` key cycles the board filter through `all`, `Todo`, `Doing` and `Done`, then back to `all`. The `Filter:` line is the first line below the rule, and the `Sort:` line follows it directly; a blank line separates them from the table. Changing either value does not move the table.

The active filter name uses the status color: Todo red, Doing cyan, Done green, and all bold white. The active sort name uses the bold selection style.

The filter applies to the task table and to the selected row. If the filter hides the selected task, the selection is clamped to the visible tasks. When a new task is created, the filter returns to `all` so the new task is visible. The category task counts remain totals and do not change with the filter.

The `o` key cycles the sort order through `original`, `status` and `title`. The original order is the insertion order. The status order groups Todo, Doing and Done, and the title order is case-insensitive. Both orders are stable, so tasks with the same status or title keep their insertion order, and the sort is applied after the filter.

When the order changes, the selected task stays selected and the cursor follows it to its new row. The same happens after a status change or an edit that moves the task in a sorted table. If the filter hides the task, the selection is clamped instead. The details and edit screens always resolve the task by identifier, so they are unaffected by the order.

## Layout

The page is composed of:

1. A solid title bar with the application name.
2. A blank line.
3. A centered subtitle with the version.
4. A blank line.
5. The category bar.
6. A full-width rule below the category bar.
7. The screen body.
8. An optional notice directly below the body, followed by a blank line before the footer.
9. A solid footer bar.
10. One or two optional prompt lines.

The board, category and help tables use the borderless mode of the Ansiform table printer. The column alignment and truncation remain.

The board table has three columns: title, note and status. The note is the main field and receives the widest column. The title is short and stays on the left. The status is a small right-aligned column with the values `Todo`, `Doing` and `Done`, each styled with its status color. Todo is red, Doing is cyan and Done is green. The filter line sits immediately below the rule, with a blank line below it before the table header.

The board table uses fixed column widths of 20 columns for the title, 40 for the note and 7 for the status, with truncation when a title or note is longer. The selected row is marked with `> ` in the title column and uses the bold selection style for the title and note. The status keeps its status color.

The details screen shows the title, status and category as compact fields, followed by the complete note in a paragraph. Paragraphs wrap to the terminal width, so long notes remain readable.

## Windowing

The task table shows at most ten tasks. The visible window follows the selection, and a row with `...` in the title column marks hidden tasks above or below. `windowAround` is pure and tested, so the selection never points outside the rendered window.

## Text input

The create, edit and category forms are built by `renderTaskForm` and `renderCategoryForm`, which return a `Page` and a list of `Prompt`s. `readForm` draws the page and reads the prompts, so the runner does not count lines or move the cursor itself. Each prompt is placed by zero-based section index, row inside the section and absolute column. `readForm` enables the editor once for the whole form and returns the updated `Draw.State` with the typed values. Every form uses `promptWithInitial`: edit forms pass the current value, and create forms pass an empty string so they use the same line editor with arrows, `Home`, `End` and `Delete`.

The task form has two prompts, title and note. The category form has one prompt. In edit mode, the form adds a hint line before the prompts and the prompt indices account for that extra section.

## Key decoding

Immediate input returns one character at a time. Arrow keys arrive as ANSI escape sequences. `readKeyEvent` reads the first character and, when it is `Esc`, waits up to 30 milliseconds for `[` or `O` and then for `A`, `B`, `C` or `D`. The Delete key is decoded from the `Esc [ 3 ~` sequence. A lone `Esc` becomes the back key. `Enter` is accepted as either carriage return or newline, and `Backspace` is accepted as either `DEL` or the backspace control character. Left and right arrows are decoded by the main loop and have no action outside a form; inside a form the Ansiform line editor reads them directly to move the cursor. Space is a normal character and is handled by the board and details screens. On terminals that do not send ANSI escape sequences, such as some Windows consoles, use `j`/`k` or `w`/`s` for vertical navigation.

## Theme

`UiTheme` wraps the Ansiform `Theme` and adds semantic styles for Todo, Doing, Done, selection and notices. Status colors are red for Todo, cyan for Doing and green for Done. The header and footer use a blue bar with white text.

Muted text is white italic, used for labels, inactive category tabs, empty placeholders and hidden-row markers. The muted gray color is reserved for horizontal rules. The selected row uses bold white, while normal table text uses vivid white. The `Categories:` label in the category bar uses the bold yellow table-header style, and the `Data file` label uses the same style; the path below it is normal text and wraps when long.

## Terminal behavior

Colors are suppressed automatically when output is not a terminal, when `NO_COLOR` is set or when `TERM=dumb`. The task table is designed for an 80-column terminal. Wider terminals simply receive more space around the header, footer and rules.
