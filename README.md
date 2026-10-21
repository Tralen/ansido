# Ansi Do!

A small task manager for the terminal, built with [Ansiform](https://hackage.haskell.org/package/ansiform).

The name combines ANSI and "do", as in things to do.

## Goal

`ansido` is a practical application of Ansiform. It exercises the library in a real program: pages, sections, tables, groups, styles, immediate input, forms, line input and redraw.

## Status

Version 0.8.2 is functional. It includes:

- Task category creation, selection, editing and deletion.
- Arrow, `j`/`k` and `w`/`s` navigation on the category screen, with `Enter` opening the board.
- A single task table with title, note and status columns, without borders.
- Vertical navigation with arrow keys, `j` and `k`, or `w` and `s`.
- A status filter that cycles through all, Todo, Doing and Done.
- `Enter` to add a task and `Space` to cycle the selected task status.
- `e` to edit the selected task or category.
- `v` to view the full note with word wrap.
- `Backspace` to go back and `Del` to delete tasks and categories.
- A help page with the data file path.
- A shared theme for header, footer and menus.
- Plain text persistence with errors as data.
- Linux, macOS and Windows builds, checked by GitHub Actions.
- `R` to redraw and `X` to exit.

The application always starts on the category screen.

## Quick start

```sh
cabal update
cabal build all
cabal run ansido
```

The data file defaults to `$HOME/.ansido/board.tsv`. Set `ANSIDO_FILE` to use another path:

```sh
ANSIDO_FILE=./workspace.tsv cabal run ansido
```

The application opens on the category screen. Press `n` to create the first category. Use `↑` and `↓` to highlight a category and `Enter` to open its board; the digits `1` to `9` open a category directly. On the task table, press `Enter` to add a task: type the title, press Enter, type the note and press Enter again. Use `↑` and `↓` to select a task, `Space` to cycle its status, `f` to filter by status, `e` to edit, `v` to read the full note, `Del` to delete it, `Backspace` to go back and `?` for the full key reference. On the category screen, `e` renames the highlighted category and `Del` deletes it together with its tasks.

## Documentation

- [Architecture](https://github.com/Tralen/ansido/blob/main/docs/architecture.md): layers, module responsibilities and the pure/IO boundary.
- [Domain](https://github.com/Tralen/ansido/blob/main/docs/domain.md): entities, invariants, transitions and errors.
- [Persistence](https://github.com/Tralen/ansido/blob/main/docs/persistence.md): file format, validation and atomic saving.
- [Interface](https://github.com/Tralen/ansido/blob/main/docs/interface.md): screens, keys, layout, theming and input.
- [Development](https://github.com/Tralen/ansido/blob/main/docs/development.md): build, tests, versioning and contribution rules.
- [Ansiform form defaults](https://github.com/Tralen/ansido/blob/main/docs/ansiform-form-defaults.md): API proposal for editable pre-filled form fields.

## Design principles

- Immutable state; every action returns a new state.
- Pure core for task transitions, sorting and filtering.
- IO only at the edges: input, drawing and persistence.
- Errors as data; no exceptions for invalid input.
- Reusable components for the header, footer, table and task rows.

## License

MIT. See [LICENSE](https://github.com/Tralen/ansido/blob/main/LICENSE).
