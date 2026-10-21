# Ansi Do!

A small task manager for the terminal, built with [Ansiform](https://hackage.haskell.org/package/ansiform).

The name combines ANSI and "do", as in things to do.

## Goal

`ansido` is a practical application of Ansiform. It exercises the library in a real program: pages, sections, tables, groups, styles, immediate input, line input and redraw.

## Status

Version 0.1.0 is functional. It includes:

- Task category creation and selection.
- A board with Todo, Doing and Done columns.
- Immediate navigation with letter shortcuts.
- Task creation, advancement and deletion.
- A task details page.
- A help page.
- A shared theme for header, footer and menus.
- Plain text persistence with errors as data.
- `R` to redraw and `X` to exit.

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

Press `c` to open categories and `n` to create the first one. Press `a` on the board to add a task, `m` to advance it, `d` to delete it and `?` for the full key reference.

## Documentation

- [Architecture](docs/architecture.md): layers, module responsibilities and the pure/IO boundary.
- [Domain](docs/domain.md): entities, invariants, transitions and errors.
- [Persistence](docs/persistence.md): file format, validation and atomic saving.
- [Interface](docs/interface.md): screens, keys, layout, theming and input.
- [Development](docs/development.md): build, tests, versioning and contribution rules.

## Design principles

- Immutable state; every action returns a new state.
- Pure core for task transitions, sorting and filtering.
- IO only at the edges: input, drawing and persistence.
- Errors as data; no exceptions for invalid input.
- Reusable components for the header, footer, board and task lines.

## License

MIT. See [LICENSE](LICENSE).
