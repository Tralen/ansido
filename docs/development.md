# Development

## Requirements

- GHC 9.14.1, the primary version used for the current release.
- GHC 9.2.8 is also covered by CI to keep the lower `base` bound honest.
- `cabal-install` 3.18 or newer.
- Fourmolu 0.21.0.0, configured by `fourmolu.yaml`.
- Ansiform 1.0.0 from Hackage.

## Commands

```sh
cabal update
cabal build all
cabal test all
cabal run ansido
```

Use a separate data file while developing:

```sh
ANSIDO_FILE=./scratch/board.tsv cabal run ansido
```

On Windows PowerShell:

```powershell
$env:ANSIDO_FILE = ".\scratch\board.tsv"; cabal run ansido
```

## Tests

The test suite is a small self-contained runner in `test/Main.hs`. It covers:

- Text validation and trimming, including task notes.
- Task and category transitions.
- Workspace invariants.
- Encode and decode round trips, version 1 compatibility, CRLF files and malformed inputs.
- Window slicing and borderless table construction with truncation.
- Arrow, Enter/Backspace/Space, Delete, W/S, edit/filter and back navigation key mapping.
- Category keys for creating, editing and deleting categories.
- Category navigation with arrows, `j`/`k`, `w`/`s` and the `Enter` board shortcut.
- Initial state on the category screen, vertical navigation, status cycling, filtering, editing, details, submit and select actions.
- Category editing, category deletion with its tasks, and the pre-filled edit prompts.
- Data file path propagation through `withDataFile`.

The current suite has 43 tests.

A failing test prints its name and message and exits with a failure code. A passing run prints the number of tests.

## Checks

Run these before preparing a release:

```sh
cabal build all --enable-tests
cabal test all
cabal check
cabal sdist
cabal haddock --haddock-for-hackage
fourmolu --mode check src test app
hlint src test app
```

`fourmolu.yaml` is the single source of the formatting style. `fourmolu --mode check src test app` reports any file that differs, and `fourmolu --mode inplace src test app` rewrites it. CI repeats the check in the `formatting` job. `hlint` reports style hints and is not a gate.

Install the Git hooks once with `pre-commit install`; they scan staged changes with gitleaks and format staged Haskell files with the local Fourmolu hook, which requires `fourmolu` on `PATH`. CI scans the full history with gitleaks through the `Secrets` workflow.

## Cross-platform

The application targets Linux, macOS and Windows. GitHub Actions runs `cabal build all`, `cabal test all`, `cabal check`, `cabal haddock` and `cabal sdist` on all three systems through `.github/workflows/ci.yml`. The matrix covers GHC 9.2.8 and 9.14.1 on each system, with Cabal 3.18.1.0. The actions are pinned by commit SHA.

The macOS job uses `macos-15` instead of `macos-latest`. The current `macos-latest` image ships the macOS 26/27 SDK, whose `arm64e.x1-macos` entries in the `.tbd` stub files are rejected by the linker that GHC 9.14.1 uses. Revisit the pin when a newer GHC links against that SDK.

- The data file uses `ANSIDO_FILE` or `getHomeDirectory`, never a hardcoded path. On Windows `getHomeDirectory` uses the profile directory, so `HOME` is optional.
- Board files are UTF-8 with Unix line endings on every platform. Reading also accepts CRLF files.
- `saveWorkspace` relies on `renameFile`, which already replaces an existing board on Windows.
- `app/Main.hs` sets the standard handles to UTF-8, so the arrows, the backspace icon and non-ASCII task text render on the Windows console.
- Arrow keys depend on the terminal sending ANSI escape sequences. Windows Terminal and modern consoles do; on a console that does not, use `j`/`k` or `w`/`s` for vertical navigation. Letter keys, Enter, Backspace and Space are decoded from plain characters and work everywhere; arrows and Delete depend on the escape sequences.

## Releases

Publishing is manual. CI only builds and tests.

### GitHub release

1. Confirm that the version in `ansido.cabal` matches the tag you are about to create, and that `CHANGELOG.md` has an entry for it.
2. Run `cabal check`, `cabal test all`, `cabal sdist` and `cabal haddock --haddock-for-hackage` locally.
3. Create a signed tag with `git tag -s v<version> -m "ansido <version>"` and push it. Verify it with `git tag -v v<version>`.
4. Run the `Release` workflow manually (`workflow_dispatch`) with the tag as input. The `release` environment gates the publish job. The workflow validates the tag against `ansido.cabal`, builds the executable on Linux, macOS and Windows, generates `SHA256SUMS`, attests build provenance and attaches the archives to the GitHub release.

Asset names follow `ansido-<version>-<os>-<arch>`. Linux and macOS use `.tar.gz`; Windows uses `.zip`. The Linux binary is built on Ubuntu 22.04 for a broader glibc range, and the macOS binary is built on `macos-15` for arm64.

### Signing

Commits and tags are signed with SSH. Git needs `gpg.format ssh`, `user.signingkey` pointing to the signing key, `commit.gpgSign true`, `tag.gpgSign true` and `gpg.ssh.allowedSignersFile` listing the signer e-mail with its public key. The public key must also be registered on GitHub as a signing key; an OpenPGP key may be registered as well, but SSH is the default here. Verify a commit with `git log --show-signature` and a tag with `git tag -v`.

### Hackage release

1. Upload a candidate first and inspect it on Hackage:

   ```sh
   cabal sdist
   cabal upload -t "$HACKAGE_TOKEN" dist-newstyle/sdist/ansido-<version>.tar.gz
   ```

2. Wait for the candidate to be reviewed.
3. Publish the same tarball only after approval:

   ```sh
   cabal upload --publish -t "$HACKAGE_TOKEN" dist-newstyle/sdist/ansido-<version>.tar.gz
   ```

4. Optionally upload the documentation with `cabal upload -d --publish -t "$HACKAGE_TOKEN"`.

The `Hackage` workflow is a manual `workflow_dispatch` alternative that runs in the `hackage` environment. It never runs on push or tag, so a candidate is always created before publication. Create the `hackage` environment and store the registry token there as the `HACKAGE_TOKEN` environment secret. The `release` environment belongs to `release.yml` and is not read by this workflow.

## Versioning

The application follows PVP, single-sourced from the `version` field in `ansido.cabal`. `Ansido.Version` reads it through the generated `Paths_ansido` module, so the interface never hardcodes a version string.

Bump rules:

- Patch for fixes and minor refinements.
- Minor for new user-facing features or screens.
- Major 2 for data model breaking changes.
- Major 1 for major release milestones.

Every release is recorded in `CHANGELOG.md`, in the section that matches the size of the change. Feature releases go under Version History; patches and refinements go under Revision History. Commit messages start with the version.

## Adding a screen

1. Add a constructor to `Screen` in `Ansido.App.State`.
2. Add the rendering branch in `Ansido.Ui.Page.screenBody` and the footer hints in `footerHints`.
3. Add an `Action` when the screen changes the state, and handle it in `Ansido.App.Update.update`.
4. Map the relevant keys in `Ansido.App.Command.commandForKey`, including arrows when the screen supports them.
5. Thread any new input through `Ansido.App.Run`, using `readForm` with prompts built from the page sections instead of counting lines.
6. Add tests for the pure update and any new pure helper.
7. Document the screen and keys in `docs/interface.md`.

## Adding a dependency

Keep the dependency footprint small. The application currently uses `base`, `ansiform`, `directory` and `filepath`. Arrow decoding uses `System.Timeout`, which is part of `base`. Persistence is deliberately plain text, so a database or serialization library is not needed. Justify any new dependency in the change summary and in this document.

## Code rules

- No reassignment or mutation after creation.
- No `for` or `while`; use `map`, `filter`, `foldr` and recursion.
- No `throw` or `panic` in application code; use `Either` and closed error types.
- No `any` or `unknown` equivalents; model states with algebraic data types.
- Use newtypes for identifiers and validated text.
- Code, comments and file names are in English.
- Comments end with a period and use commas or semicolons instead of em dashes.

## Cabal notes

`cabal-version: 2.4` is the version of the `.cabal` file specification, not the version of the installed `cabal-install` tool. The tool is 3.18, but the package file uses the 2.4 specification because the project needs only features available there and this keeps the file readable by older toolchains. The `cabal-version` field should be raised only when the file starts using a newer specification feature.

`Paths_ansido` is listed in both `autogen-modules` and `other-modules`, because Cabal 3.18 rejects an autogenerated module that is not exposed or listed as an internal module. The Ansiform umbrella module exports `renderPage`; the application hides that name in the modules that define their own `renderPage`.
