# Ansi Do!

A small task manager for the terminal, built with [Ansiform](https://hackage.haskell.org/package/ansiform).

The name combines ANSI and "do", as in things to do.

## Stack

Haskell with Cabal, using [Ansiform](https://hackage.haskell.org/package/ansiform) for the terminal interface. Stack is not used.

## Versioning

PVP, single-sourced from the `ansido.cabal` file.

- Patch: fixes and minor refinements.
- Minor: new user-facing features or screens.
- Major 2: data model breaking changes.
- Major 1: major release milestones.

## Goal

`ansido` is a practical application of Ansiform. It exercises the library in a real program: pages, sections, tables, groups, styles, immediate input, forms, line input and redraw.

## Status

Version 0.9.0 is functional. It includes:

- Task category creation, selection, editing and deletion.
- Arrow, `j`/`k` and `w`/`s` navigation on the category screen, with `Enter` opening the board.
- A single task table with title, note and status columns, without borders.
- Vertical navigation with arrow keys, `j` and `k`, or `w` and `s`.
- A status filter that cycles through all, Todo, Doing and Done.
- `Enter` to add a task and `Space` to cycle the selected task status.
- `e` to edit the selected task or category, with the current values pre-filled in the form.
- `v` to view the full note with word wrap.
- `Backspace` to go back and `Del` to delete tasks and categories.
- A help page with the data file path.
- A shared theme for header, footer and menus.
- Plain text persistence with errors as data.
- Linux, macOS and Windows builds, checked by GitHub Actions.
- Release binaries for all three systems on GitHub Releases.
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

The application opens on the category screen. Press `n` to create the first category. Use `↑` and `↓` to highlight a category and `Enter` to open its board; the digits `1` to `9` open a category directly. On the task table, press `Enter` to add a task: type the title, press Enter, type the note and press Enter again. Use `↑` and `↓` to select a task, `Space` to cycle its status, `f` to filter by status, `e` to edit, `v` to read the full note, `Del` to delete it, `Backspace` to go back and `?` for the full key reference. On the category screen, `e` renames the highlighted category and `Del` deletes it together with its tasks. The edit forms open with the current values pre-filled, so only the changed part has to be retyped.

Pre-built binaries for Linux, macOS and Windows are attached to each GitHub release.

## Documentation

- [Architecture](https://github.com/Tralen/ansido/blob/main/docs/architecture.md): layers, module responsibilities and the pure/IO boundary.
- [Domain](https://github.com/Tralen/ansido/blob/main/docs/domain.md): entities, invariants, transitions and errors.
- [Persistence](https://github.com/Tralen/ansido/blob/main/docs/persistence.md): file format, validation and atomic saving.
- [Interface](https://github.com/Tralen/ansido/blob/main/docs/interface.md): screens, keys, layout, theming and input.
- [Development](https://github.com/Tralen/ansido/blob/main/docs/development.md): build, tests, versioning and contribution rules.
- [Ansiform form initial values](https://github.com/Tralen/ansido/blob/main/docs/ansiform-form-defaults.md): editable pre-filled form fields and how ansido uses them.

## Design principles

- Immutable state; every action returns a new state.
- Pure core for task transitions, sorting and filtering.
- IO only at the edges: input, drawing and persistence.
- Errors as data; no exceptions for invalid input.
- Reusable components for the header, footer, table and task rows.

## License

MIT. See [LICENSE](https://github.com/Tralen/ansido/blob/main/LICENSE).
