# Interface

The interface is built with Ansiform pages, sections, groups, tables and immediate input.

## Screens

| Screen | Purpose |
| --- | --- |
| Board | Todo, Doing and Done columns for the selected category. |
| Details | Read-only view of the selected task. |
| Help | Key reference in a bordered table. |
| Categories | Category list with task counts and selection. |
| Add task | Board preview with a title prompt at the bottom. |
| Add category | Category preview with a name prompt at the bottom. |

Every screen shares the same header, category bar and footer. The header shows the application name and version. The category bar always shows all categories, with the active one highlighted. The footer lists the shortcuts available on the current screen.

## Keys

### Board

| Key | Action |
| --- | --- |
| `h` / `l` | Move one column left or right. |
| `j` / `k` | Move one row down or up. |
| `1` / `2` / `3` | Focus Todo, Doing or Done. |
| `a` | Open the new task prompt. |
| `m` | Advance the selected task along the status cycle. |
| `d` | Delete the selected task. |
| `v` | Open task details. |
| `c` | Open the category screen. |
| `?` | Open help. |
| `r` | Redraw the current page. |
| `x` | Exit. |

### Details

`b` or `Esc` returns to the board, `m` advances the task, `d` deletes it, `?` opens help and `x` exits.

### Categories

`n` opens the new category prompt, `1` to `9` select a category, `b` or `Esc` returns to the board and `x` exits.

### Help

`b`, `?` or `Esc` returns to the board. `x` exits.

### Prompts

The prompt accepts a line of text and confirms with `Enter`. Empty input cancels the prompt and returns to the previous screen. Input is validated by the domain smart constructors, so an empty title, an overlong title or a title with control characters becomes a notice instead of a broken record.

## Layout

The page is composed of:

1. A rule and a solid title bar.
2. A centered subtitle with the version.
3. The category bar.
4. An optional notice.
5. The screen body.
6. A solid footer bar.
7. An optional prompt line.

The board uses three Ansiform groups inside a light border. Each group has a header with the status and task count. Column bodies are padded to the same height before rendering, because the bordered group printer expects every column to have the same number of blocks.

## Windowing

A column shows at most eight tasks. The visible window follows the selection, and a muted `...` line marks hidden tasks above or below. `windowAround` is pure and tested, so the selection never points outside the rendered window.

## Truncation

Task titles are truncated to 20 visible columns, including the three dots. `truncateVisible` uses Ansiform's `textWidth` and `charWidth`, so wide characters and combining marks do not break the alignment.

## Text input

Prompts are drawn as the last section of the page. `readLineAt 1 column` moves the cursor up to the prompt line and places it after the label. The function already wraps `withLineInput`, so it must not be wrapped again. After `Enter`, the cursor sits one line below the prompt, matching the line count tracked by `Draw.State`.

## Theme

`UiTheme` wraps the Ansiform `Theme` and adds semantic styles for Todo, Doing, Done, selection and notices. Status colors are yellow for Todo, cyan for Doing and green for Done. The header and footer use a blue bar with white text. Muted text uses the vivid black color, which most terminals render as gray.

## Terminal behavior

Colors are suppressed automatically when output is not a terminal, when `NO_COLOR` is set or when `TERM=dumb`. The board targets an 80-column terminal: three columns of at most 24 content columns plus borders fit within that width. Wider terminals simply receive more space around the header and footer bars.
