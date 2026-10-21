# Interface

The interface is built with Ansiform pages, sections, groups, tables and immediate input.

## Screens

| Screen | Purpose |
| --- | --- |
| Board | Todo, Doing and Done columns for the selected category. |
| Details | Read-only view of the selected task, including its note. |
| Help | Key reference in a bordered table. |
| Categories | Category list with task counts and selection. |
| Add task | Board preview with title and note prompts at the bottom. |
| Add category | Category preview with a name prompt at the bottom. |

Every screen shares the same header, category bar and footer. The header shows the application name and version. The category bar always shows all categories, with the active one highlighted. The footer lists the shortcuts available on the current screen.

## Keys

### Board

| Key | Action |
| --- | --- |
| `↑` / `↓` | Move one row up or down. |
| `←` / `→` | Move one column left or right. |
| `h` / `j` / `k` / `l` | Vim-style alternative to the arrow keys. |
| `1` / `2` / `3` | Focus Todo, Doing or Done. |
| `a` | Open the new task prompt. |
| `m` | Advance the selected task along the status cycle. |
| `d` | Delete the selected task. |
| `v` | Open task details. |
| `c` | Open the category screen directly. |
| `b` or `Esc` | Go back to the category selection. |
| `?` | Open help. |
| `r` | Redraw the current page. |
| `x` | Exit. |

### Details

`b` or `Esc` returns to the board, `m` advances the task, `d` deletes it, `?` opens help and `x` exits.

### Categories

`n` opens the new category prompt, `1` to `9` select a category, `b` or `Esc` returns to the board and `x` exits.

### Help

`b`, `?` or `Esc` returns to the board. `x` exits.

### Back navigation

The back key follows the screen hierarchy: details returns to the board, and the board returns to the category selection. From the category selection, back returns to the board. This makes `b` a consistent way to leave the notes view and reach the categories.

### Prompts

The task prompt has two lines: the title and the note. Type the title, press `Enter`, type the note and press `Enter` again. An empty title cancels the prompt. An empty note is valid and creates a task with `(empty)` on the details screen. The category prompt has a single line. Empty category input cancels and returns to the category selection.

Input is validated by the domain smart constructors, so an overlong title, an overlong note or a text with control characters becomes a notice instead of a broken record.

## Layout

The page is composed of:

1. A solid title bar with the application name.
2. A blank line.
3. A centered subtitle with the version.
4. The category bar.
5. A full-width rule below the category bar.
6. An optional notice.
7. The screen body.
8. A solid footer bar.
9. One or two optional prompt lines.

The board uses three Ansiform groups inside a light border. Each group has a header with the status and task count. Column bodies are padded to the same height before rendering, because the bordered group printer expects every column to have the same number of blocks.

## Windowing

A column shows at most eight tasks. The visible window follows the selection, and a muted `...` line marks hidden tasks above or below. `windowAround` is pure and tested, so the selection never points outside the rendered window.

## Truncation

Task titles are truncated to 20 visible columns, including the three dots. `truncateVisible` uses Ansiform's `textWidth` and `charWidth`, so wide characters and combining marks do not break the alignment.

## Text input

Prompts are drawn as the last sections of the page. For a new task, the title prompt is two lines above the final cursor position, so the runner calls `readLineAt 2`. After the title is confirmed, the cursor sits on the note prompt line, so the runner calls `readLineAt 0`. For a category, the single prompt is one line above the final cursor position, so the runner calls `readLineAt 1`.

`readLineAt` already wraps `withLineInput`, so it must not be wrapped again. After the last `Enter`, the cursor sits one line below the last prompt, matching the line count tracked by `Draw.State`.

## Key decoding

Immediate input returns one character at a time. Arrow keys arrive as ANSI escape sequences. `readKeyEvent` reads the first character and, when it is `Esc`, waits up to 30 milliseconds for `[` or `O` and then for `A`, `B`, `C` or `D`. A lone `Esc` becomes the back key. Unrecognized sequences are treated as the back key.

## Theme

`UiTheme` wraps the Ansiform `Theme` and adds semantic styles for Todo, Doing, Done, selection and notices. Status colors are yellow for Todo, cyan for Doing and green for Done. The header and footer use a blue bar with white text. Muted text uses the vivid black color, which most terminals render as gray.

## Terminal behavior

Colors are suppressed automatically when output is not a terminal, when `NO_COLOR` is set or when `TERM=dumb`. The board targets an 80-column terminal: three columns of at most 24 content columns plus borders fit within that width. Wider terminals simply receive more space around the header and footer bars.
