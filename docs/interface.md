# Interface

The interface is built with Ansiform pages, sections, borderless tables, forms and immediate input.

## Screens

| Screen | Purpose |
| --- | --- |
| Categories | Category list with task counts and selection. This is always the initial screen. |
| Board | Task table with title, note and state for the selected category, with a live state filter. |
| Details | Full task view with the complete note wrapped across lines. |
| Edit task | Task form with the current content above the prompts. |
| Help | Key reference in a borderless table, followed by the data file path. |
| Add task | Task table preview with title and note prompts at the bottom. |
| Add category | Category preview with a name prompt at the bottom. |

Every screen shares the same header, category bar and footer. The header shows the application name and version. The category bar always shows all categories, with the active one highlighted. The footer lists the shortcuts available on the current screen.

## Keys

### Board

| Key | Action |
| --- | --- |
| `↑` / `↓` | Select the previous or next task. |
| `j` / `k` | Vim-style alternative to the vertical arrow keys. |
| `w` / `s` | WASD-style alternative to the vertical arrow keys. |
| `Enter` | Open the new task prompt. |
| `Space` | Cycle the selected task state forward. |
| `e` | Edit the selected task. |
| `f` | Cycle the state filter. |
| `Del` | Delete the selected task. |
| `v` | Open the full task view. |
| `Backspace` or `Esc` | Go back to the category selection. |
| `?` | Open help. |
| `r` | Redraw the current page. |
| `x` | Exit. |

The state cycle is `Todo -> Doing -> Done -> Todo`. The selected row stays in place because the table keeps insertion order.

### Details

`Backspace` or `Esc` returns to the board, `Space` cycles the task state, `e` edits the task, `Del` deletes it, `?` opens help and `x` exits. The complete note is shown with word wrap.

### Edit task

The edit screen reuses the task form and shows the current title, state, category and note above the prompts. The prompt labels also include the current title and note, truncated to 20 columns, so the input context stays visible even at the bottom of the page. Type a new value or press `Enter` to keep the current one. An empty title and an empty note both keep their current values. The edit is submitted after the note prompt, and the board returns with a confirmation notice.

Ansiform forms read complete lines, so the current value is shown in the prompt label rather than as an editable pre-filled buffer. Empty input means "keep current".

### Categories

`n` opens the new category prompt, `1` to `9` select a category, `Backspace` or `Esc` returns to the board and `x` exits.

### Help

`Backspace`, `?` or `Esc` returns to the board. `x` exits.

### Back navigation

The back key follows the screen hierarchy: details and edit return to the board, the board returns to the category selection, the category selection returns to the board and help returns to the board. `Backspace` is the primary back key, and `Esc` is an alternative.

### Prompts

The create form has two lines: the title and the note. Type the title, press `Enter`, type the note and press `Enter` again. An empty title cancels the create prompt. An empty note is valid and creates a task with `(empty)` in the note column. The category prompt has a single line. Empty category input cancels and returns to the category selection.

Input is validated by the domain smart constructors, so an overlong title, an overlong note or a text with control characters becomes a notice instead of a broken record.

## Filtering

The `f` key cycles the board filter through `all`, `Todo`, `Doing` and `Done`, then back to `all`. The `Filter:` line is the first line below the rule, with a blank line after it, so changing the filter does not move the table. The active filter name uses the state color: Todo red, Doing cyan, Done green, and all bold white.

The filter applies to the task table and to the selected row. If the filter hides the selected task, the selection is clamped to the visible tasks. When a new task is created, the filter returns to `all` so the new task is visible. The category task counts remain totals and do not change with the filter.

## Layout

The page is composed of:

1. A solid title bar with the application name.
2. A blank line.
3. A centered subtitle with the version.
4. A blank line.
5. The category bar.
6. A full-width rule below the category bar.
7. The screen body.
8. An optional notice below the body.
9. A solid footer bar.
10. One or two optional prompt lines.

The board and category tables have no borders. The help table is also borderless. The column alignment and truncation from the shared row renderer remain.

The board table has three columns: title, note and state. The note is the main field and receives the widest column. The title is short and stays on the left. The state is a small right-aligned column with the values `Todo`, `Doing` and `Done`, each styled with its status color. Todo is red, Doing is cyan and Done is green. The filter line sits immediately below the rule, with a blank line below it before the table header.

The shared row renderer uses per-column maximum widths of 20 columns for the title, 40 for the note and 7 for the state, with an ellipsis when a title or note is truncated. The selected row is marked with `> ` in the title column and uses the bold selection style for the title and note. The state keeps its status color.

The details screen shows the title, state and category as compact fields, followed by the complete note in a paragraph. Paragraphs wrap to the terminal width, so long notes remain readable.

## Windowing

The task table shows at most ten tasks. The visible window follows the selection, and a row with `...` in the title column marks hidden tasks above or below. `windowAround` is pure and tested, so the selection never points outside the rendered window.

## Text input

The create, edit and category forms are built by `renderTaskForm` and `renderCategoryForm`, which return a `Page` and a list of `Prompt`s. `readForm` draws the page and reads the prompts, so the runner does not count lines or move the cursor itself. Each prompt is placed by zero-based section index, row inside the section and absolute column. `readForm` enables line input once for the whole form and returns the updated `Draw.State` with the typed values.

The task form has two prompts, title and note. The category form has one prompt. In edit mode, the form adds a hint line before the prompts saying that empty input keeps the current value, and the prompt indices account for that extra section.

## Key decoding

Immediate input returns one character at a time. Arrow keys arrive as ANSI escape sequences. `readKeyEvent` reads the first character and, when it is `Esc`, waits up to 30 milliseconds for `[` or `O` and then for `A`, `B`, `C` or `D`. The Delete key is decoded from the `Esc [ 3 ~` sequence. A lone `Esc` becomes the back key. `Enter` is accepted as either carriage return or newline, and `Backspace` is accepted as either `DEL` or the backspace control character. Left and right arrows are decoded but have no action. Space is a normal character and is handled by the board and details screens.

## Theme

`UiTheme` wraps the Ansiform `Theme` and adds semantic styles for Todo, Doing, Done, selection and notices. Status colors are red for Todo, cyan for Doing and green for Done. The header and footer use a blue bar with white text.

Muted text is white italic, used for labels, inactive category tabs, empty placeholders and hidden-row markers. The muted gray color is reserved for horizontal rules. The selected row uses bold white, while normal table text uses vivid white. The `Data file` label uses the bold yellow table-header style; the path below it is normal text and wraps when long.

## Terminal behavior

Colors are suppressed automatically when output is not a terminal, when `NO_COLOR` is set or when `TERM=dumb`. The task table is designed for an 80-column terminal. Wider terminals simply receive more space around the header, footer and rules.
