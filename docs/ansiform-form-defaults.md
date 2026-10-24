# Ansiform form initial values

Ansiform 1.0 implements editable form fields with an initial value. `ansido` uses the feature in both edit modes, so the user changes only the part of the value that needs to change.

This document used to be a proposal for the library. It now describes the implemented API and how the application uses it.

## API

`Prompt` carries an optional initial value:

```haskell
data Prompt = Prompt
  { promptSection :: Number
  , promptRow     :: Number
  , promptColumn  :: Offset
  , promptInitial :: Maybe String
  }
```

`promptAt` builds a prompt without an initial value and keeps the original behaviour. `promptWithInitial` seeds the editable line:

```haskell
promptAt :: Number -> Number -> Offset -> Prompt
promptWithInitial :: Number -> Number -> Offset -> String -> Prompt
```

The initial value is filtered with `isPrint`, because the editor is single-line.

## Reading a form

`readForm :: Page -> [Prompt] -> State -> IO (State, Either FormError [String])` draws the page and reads one line per prompt.

- A prompt built with `promptAt` uses the terminal line discipline and `readLine`.
- A prompt built with `promptWithInitial` uses the Ansiform line editor when stdin is a terminal, so the value can be changed in place.
- When stdin is not a terminal, the editor falls back to `readLine` and ignores the initial value.
- The result is the exact edited buffer for every prompt. The form does not apply "empty means keep current"; that decision belongs to the caller.
- `Esc` cancels the form with `FormCancelled`, end of input returns `FormInputEnded`, and a prompt outside the page returns `PromptOutsidePage` before any input is read.

The line editor supports printable characters, `Backspace`, `Delete`, `Left`, `Right`, `Home`, `End`, `Enter` and `Esc`. The cursor starts at the end of the buffer, and long values scroll horizontally.

## Use in ansido

`renderTaskForm` and `renderCategoryForm` build every prompt with `promptWithInitial`. Edit forms pass the current value; create forms pass an empty string, which the editor treats as an empty editable buffer. This gives every form the same cursor movement, deletion and insertion keys, instead of leaving the create forms on the terminal line discipline.

- Edit task: the title and note prompts start with the current title and note.
- Edit category: the name prompt starts with the current name.
- Create task and create category: the prompts start empty but remain editable.
- The hint above the prompts reads `Edit the value and press Enter.` in edit mode.

Because the field already contains the current value, empty input is no longer a request to keep it:

- An empty title or category name is rejected by the domain and becomes a notice.
- An empty note is valid and clears the note.
- In create mode, an empty title or category name still cancels before the domain sees it.

The details body above the task form still shows the title, status, category and note for context. The category form shows the name and task count.

## Dependency

`ansido` requires `ansiform >= 1.0 && < 1.1`. Earlier Ansiform releases only had `promptAt`, which is why the edit forms used to show the current value above empty prompts and treated empty input as "keep current". Ansiform 1.0 added `promptWithInitial`, and its empty initial value is what lets the create forms use the same line editor.
