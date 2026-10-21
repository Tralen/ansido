# Ansiform form defaults

This document proposes an Ansiform API for form fields that start with an editable value. It is written for the library author: the goal is to explain the problem, the constraints and a concrete design, not to change `ansido` behaviour.

## Context

`Ansiform.Input` currently offers two line-reading paths:

- `readLineAt :: Number -> Offset -> IO (Maybe String)` moves the cursor to a prompt line, enables line input with echo and calls `readLine`.
- `readForm :: Page -> [Prompt] -> State -> IO (State, Either FormError [String])` draws a page, computes the absolute line of each `Prompt`, enables line input once and reads one line per prompt.

`Prompt` stores a zero-based section index, a row inside the section and an absolute column. `promptAt` builds a prompt with those three values. `readForm` uses the line counts from the `State` produced by drawing the page, so callers do not count lines themselves.

The line input path is `readLine`, which calls `getLine`. The terminal's line discipline owns the editable buffer and the echo. This is why the current API can place a prompt precisely but cannot seed the input line.

## The problem

A form field with an initial value needs the text to be in the editable buffer when the field opens. The user should be able to move the cursor, delete characters, insert text and submit the result without retyping the whole value.

`getLine` cannot do this:

1. The buffer starts empty; the terminal has no concept of an initial buffer.
2. Text printed on the prompt line before `getLine` is only display. It is not part of the returned string.
3. The terminal's line discipline redraws and edits its own buffer. An application cannot insert text into that buffer portably.
4. Simulating Ctrl+V is not an API. A program can set the clipboard (for example with OSC 52) but cannot send the paste keystroke to the terminal. Injecting input through `TIOCSTI` is platform-specific, often disabled and unsafe. Bracketed paste is driven by the terminal, not by the application.

The current workarounds in `ansido` show the limit:

- The edit form shows the current title and note above the prompts and treats empty input as "keep current". The user sees the value, but the field itself is empty.
- Putting the current value in the prompt label (`Task title [current]:`) was removed because it is visual noise, not an editable field.
- The user still has to retype the value to change part of it.

The missing abstraction is a small line editor owned by Ansiform. It would own the buffer, the cursor, echo and redraw, while Ansiform already owns the page and the prompt placement.

## Goals and non-goals

Goals:

- A form prompt can carry an optional initial value.
- A prompt with an initial value opens with an editable buffer in place.
- The editor is single-line, Unicode-width aware and uses `Ansiform.Width`.
- The existing `promptAt` and `readForm` behaviour is preserved for prompts without an initial value.
- Errors remain data: cancellation and end of input are explicit results.
- The pure editing logic is testable without a terminal.

Non-goals:

- Multi-line text areas or paragraph editing.
- Grapheme-cluster-aware cursor movement. Editing is by Unicode code point; combining marks may be split when moving.
- Full readline feature parity (history, completion, kill ring, word movement).
- Clipboard integration or simulated Ctrl+C/Ctrl+V.
- Mouse support.

## Proposed public API

Extend `Prompt` with an optional initial value and keep the existing smart constructor:

```haskell
data Prompt = Prompt
  { promptSection :: Number
  , promptRow     :: Number
  , promptColumn  :: Offset
  , promptInitial :: Maybe String
  }

promptAt :: Number -> Number -> Offset -> Prompt
promptAt sectionIndex row column =
  Prompt sectionIndex row column Nothing

promptWithInitial :: Number -> Number -> Offset -> String -> Prompt
promptWithInitial sectionIndex row column initial =
  Prompt sectionIndex row column (Just (filter isPrint initial))
```

`promptAt` keeps the current behaviour: the field is read with `getLine` and the terminal's own line editing. `promptWithInitial` opts into the Ansiform line editor. `Just ""` is meaningful: it opens the editor with an empty buffer, which is useful when the form should use the same editor for every field.

Add a cancellation result:

```haskell
data FormError
  = PromptOutsidePage Prompt
  | FormInputEnded
  | FormCancelled
  deriving (Eq, Show)
```

Semantics of `readForm`:

1. Draw the page and compute the prompt lines, as today.
2. For each prompt in order:
   - If `promptInitial` is `Nothing`, use the current `readLine` path.
   - If `promptInitial` is `Just initial` and stdin is a terminal, run the Ansiform line editor seeded with `initial` and return the edited buffer.
   - If stdin is not a terminal, fall back to `readLine` and ignore the initial value. The editor is a UI affordance; non-interactive consumers should send explicit values.
3. `Enter` submits the current field and moves to the next prompt.
4. `Esc` cancels the whole form and returns `Left FormCancelled`.
5. End of input returns `Left FormInputEnded`.
6. A prompt outside the page returns `Left (PromptOutsidePage prompt)` before any input is read.

The form returns the exact edited buffers. It does not apply "empty means keep" semantics; that decision belongs to the caller.

Example:

```haskell
let prompts =
      [ promptWithInitial 2 0 14 (taskTitle task)
      , promptWithInitial 3 0 14 (taskContent task)
      ]

(updatedState, result) <- readForm page prompts currentState

case result of
  Left FormCancelled -> cancelEdit
  Left FormInputEnded -> finishInput
  Left (PromptOutsidePage bad) -> reportBadPrompt bad
  Right [title, note] -> saveEdit title note
```

## Line editor behaviour

### Key map

| Key | Action |
| --- | --- |
| Printable character | Insert at the cursor. |
| `Backspace` (`DEL` or `\b`) | Delete the character before the cursor. |
| `Delete` (`Esc [ 3 ~`) | Delete the character at the cursor. |
| `Left` / `Right` (`Esc [ D` / `Esc [ C`) | Move the cursor one code point. |
| `Home` / `End` (`Esc [ H` / `Esc [ F`, `Esc [ 1 ~` / `Esc [ 4 ~`) | Move to the start or end of the buffer. |
| `Enter` (`\r` or `\n`) | Submit the field. |
| `Esc` | Cancel the form. |
| Unknown sequence | Ignore. |

The initial cursor position is at the end of the buffer. Selecting the whole buffer on open would be a different edit model; end-of-buffer is predictable and matches most shell prompts.

### Display

The buffer is single-line. The editor owns the region from `promptColumn` to the end of the line: it clears that region and redraws the visible window on every key. Callers should keep the prompt line clear after the prompt column.

The available width is the terminal width minus `promptColumn`, optionally minus one column for the cursor. If the buffer does not fit, the editor shows a window that contains the cursor and scrolls horizontally. `visibleLine` should use `textWidth` and `charWidth` so wide characters and combining marks do not break the cursor column.

On `Enter`, print a newline so the cursor ends one line below the prompt, matching the behaviour of `getLine` and the line counts used by `readForm`. On `Esc`, print a newline before returning so the caller can redraw the page cleanly.

### Pure core

Keep the buffer and cursor pure and testable:

```haskell
data LineState = LineState
  { lineText   :: String
  , lineCursor :: Int
  }

data LineKey
  = LineInsert Char
  | LineBackspace
  | LineDelete
  | LineMoveLeft
  | LineMoveRight
  | LineMoveHome
  | LineMoveEnd
  deriving (Eq, Show)

applyLineKey :: LineKey -> LineState -> LineState

-- Visible text and the cursor offset in display columns.
visibleLine :: Int -> LineState -> (String, Int)
```

`lineCursor` is a code-point index. `visibleLine` is the only width-aware function. The IO loop only decodes keys, calls `applyLineKey`, redraws with `visibleLine` and handles submit/cancel/end.

Suggested internal module: `Ansiform.Internal.Line`. Public exposure is optional; the line editor is an implementation detail behind `readForm`.

### IO loop sketch

```haskell
readLineEditor :: Handle -> Offset -> String -> IO (Either LineError String)
readLineEditor handle column initial = do
  interactive <- hIsTerminalDevice stdin
  if not interactive
    then Right <$> readLineOrEmpty
    else do
      let start = LineState initial (length initial)
      redraw handle column start
      loop handle column start
  where
    loop handle column state = do
      key <- readKeyEvent
      case key of
        Nothing -> pure (Left LineInputEnded)
        Just Escape -> do
          newline handle
          pure (Left LineCancelled)
        Just Enter -> do
          newline handle
          pure (Right (lineText state))
        Just (Edit editKey) -> do
          let state' = applyLineKey editKey state
          redraw handle column state'
          loop handle column state'
        Just _ -> loop handle column state
```

`readKeyEvent` is a small decoder over `readKey` with a short timeout for escape sequences. `redraw` moves to the prompt column, writes the visible window, clears to the end of the line and puts the cursor at the display offset.

## Compatibility and versioning

The `Prompt` constructor is not exported; `promptAt` is the public builder. Adding a `promptInitial` field is therefore source-compatible for users who build prompts with `promptAt`. `Prompt` still derives `Eq` and `Show`; those instances will include the new field.

Adding `FormCancelled` to `FormError` is a breaking change for code that pattern matches exhaustively on `FormError`. For a pre-1.0 package, a minor release such as `0.8.0` is a reasonable place for it. If a strictly non-breaking release is required, the alternative is a separate entry point:

```haskell
data FormOutcome = FormSubmitted [String] | FormCancelled

readFormWithDefaults
  :: Page -> [Prompt] -> State
  -> IO (State, Either FormError FormOutcome)
```

This keeps `readForm` and `FormError` untouched, at the cost of a second form function and a second result type. The recommendation is to extend `readForm` and `FormError` and bump the minor version, because cancel and end-of-input are both normal form outcomes and deserve a single, consistent API.

## Alternatives considered

### Current workaround: show values above, empty means keep

`ansido` does this today. It avoids a line editor, but the field is empty and the user must retype the value to change part of it. It does not solve the user request.

### Prompt label with the current value

`Task title [current]:` is easy to render, but it is not an editable field. It also makes the prompt long and was rejected as noisy.

### Haskeline

`System.Console.Haskeline.getInputLineWithInitial` already supports an initial buffer and rich editing. However, Haskeline owns its prompt, output and terminal mode. It does not integrate with Ansiform's page cursor placement or `Draw.State`, and it adds a second input model and a dependency. It is a reasonable choice for a standalone prompt, not for a field inside an Ansiform page.

### A public `readLineEditor` only

Exposing the editor without linking it to `Prompt` is a smaller change, but every caller would have to position the cursor, manage the form order and handle redraw. The `Prompt` initial value is the ergonomic API for the library's existing form abstraction.

## Test plan

- Pure tests for `applyLineKey`: insert at the start, middle and end; Backspace and Delete at both boundaries; left, right, home and end.
- Pure tests for `visibleLine`: ASCII that fits, ASCII that scrolls, wide characters, combining marks, cursor at both ends.
- Non-terminal `readForm` test: a handle fed by a temp file reads lines and ignores initial values.
- Existing `readForm` and `readLineAt` tests must keep passing; prompts built with `promptAt` must behave exactly as before.
- Demo: an edit form using `promptWithInitial`, with a long note to exercise horizontal scrolling.
- Manual terminal checklist: Enter, Backspace, Delete, arrows, Home, End, Esc cancellation and cursor visibility at both ends of a long line.

## Open questions

1. Should `Esc` cancel the whole form or only the current field? Recommendation: the whole form, because a partially completed form is rarely useful and the caller can reopen it.
2. Should the initial cursor be at the end or should the whole buffer be selected? Recommendation: end.
3. Should `Just ""` use the editor or fall back to `getLine`? Recommendation: use the editor, so a form can opt into consistent editing for all fields.
4. Should the editor support Ctrl+A, Ctrl+E, Ctrl+U and Ctrl+K? They are cheap to add, but they expand the documented key map. Start with the table above and add them only if the demo needs them.
5. Should `promptWithInitial` reject non-printable characters or replace them? Recommendation: filter them with `isPrint` and document the single-line limitation.
6. Should non-terminal input use the initial value when the line is empty? Recommendation: no; keep the interpreter neutral and let the caller decide.
