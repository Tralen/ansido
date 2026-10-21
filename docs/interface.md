# Interface

The interface is built with Ansiform pages, sections, tables and immediate input.

## Screens

| Screen | Purpose |
| --- | --- |
| Categories | Category list with task counts and selection. This is always the initial screen. |
| Board | Task table with title, note and state for the selected category. |
| Help | Key reference in a bordered table. |
| Add task | Task table preview with title and note prompts at the bottom. |
| Add category | Category preview with a name prompt at the bottom. |

Every screen shares the same header, category bar and footer. The header shows the application name and version. The category bar always shows all categories, with the active one highlighted. The footer lists the shortcuts available on the current screen.

## Keys

### Board

| Key | Action |
| --- | --- |
| `↑` / `↓` | Select the previous or next task. |
| `j` / `k` | Vim-style alternative to the vertical arrow keys. |
| `Enter` | Move the selected task to the next state. |
| `Backspace` | Move the selected task to the previous state. |
| `a` | Open the new task prompt. |
| `d` | Delete the selected task. |
| `c` | Open the category screen directly. |
| `b` or `Esc` | Go back to the category selection. |
| `?` | Open help. |
| `r` | Redraw the current page. |
| `x` | Exit. |

The states cycle in both directions: `Todo -> Doing -> Done -> Todo` for `Enter` and `Todo -> Done -> Doing -> Todo` for `Backspace`. The selected row stays in place because the table keeps insertion order.

### Categories

`n` opens the new category prompt, `1` to `9` select a category, `b` or `Esc` returns to the board and `x` exits.

### Help

`b`, `?` or `Esc` returns to the board. `x` exits.

### Back navigation

The back key follows the screen hierarchy: the board returns to the category selection, and the category selection returns to the board. The help screen returns to the board.

### Prompts

The task prompt has two lines: the title and the note. Type the title, press `Enter`, type the note and press `Enter` again. An empty title cancels the prompt. An empty note is valid and creates a task with `(empty)` in the note column. The category prompt has a single line. Empty category input cancels and returns to the category selection.

Input is validated by the domain smart constructors, so an overlong title, an overlong note or a text with control characters becomes a notice instead of a broken record.

## Layout

The page is composed of:

1. A solid title bar with the application name.
2. A blank line.
3. A centered subtitle with the version.
4. A blank line.
5. The category bar.
6. A full-width rule below the category bar.
7. An optional notice.
8. The screen body.
9. A solid footer bar.
10. One or two optional prompt lines.

The board is a single bordered table with three columns: title, note and state. The note is the main field and receives the widest column. The title is short and stays on the left. The state is a small right-aligned column with the values `Todo`, `Doing` and `Done`, each styled with its status color.

The table format uses per-column maximum widths of 20 columns for the title, 40 for the note and 7 for the state, with an ellipsis when a title or note is truncated. The selected row is marked with `> ` in the title column and uses the bold selection style for the title and note. The state keeps its status color.

## Windowing

The task table shows at most ten tasks. The visible window follows the selection, and a row with `...` in the title column marks hidden tasks above or below. `windowAround` is pure and tested, so the selection never points outside the rendered window.

## Text input

Prompts are drawn as the last sections of the page. For a new task, the title prompt is two lines above the final cursor position, so the runner calls `readLineAt 2`. After the title is confirmed, the cursor sits on the note prompt line, so the runner calls `readLineAt 0`. For a category, the single prompt is one line above the final cursor position, so the runner calls `readLineAt 1`.

`readLineAt` already wraps `withLineInput`, so it must not be wrapped again. After the last `Enter`, the cursor sits one line below the last prompt, matching the line count tracked by `Draw.State`.

## Key decoding

Immediate input returns one character at a time. Arrow keys arrive as ANSI escape sequences. `readKeyEvent` reads the first character and, when it is `Esc`, waits up to 30 milliseconds for `[` or `O` and then for `A`, `B`, `C` or `D`. A lone `Esc` becomes the back key. `Enter` is accepted as either carriage return or newline, and `Backspace` is accepted as either `DEL` or the backspace control character. Left and right arrows are decoded but have no action.

## Theme

`UiTheme` wraps the Ansiform `Theme` and adds semantic styles for Todo, Doing, Done, selection and notices. Status colors are yellow for Todo, cyan for Doing and green for Done. The header and footer use a blue bar with white text.

Muted text is white italic, used for labels, inactive category tabs, empty placeholders and hidden-row markers. The muted gray color is reserved for horizontal rules. The selected row uses bold white, while normal table text uses vivid white.

## Terminal behavior

Colors are suppressed automatically when output is not a terminal, when `NO_COLOR` is set or when `TERM=dumb`. The task table is designed for an 80-column terminal: the three columns, padding and borders fit within 80 columns. Wider terminals simply receive more space around the header, footer and rules.
