-- | Reusable interface components.
--
-- Screens are assembled from these builders so the header, footer, category
-- bar and notices behave the same everywhere.
module Ansido.Ui.Components
    ( NoticeKind (..)
    , Notice (..)
    , headerSection
    , footerSection
    , titleSection
    , categorySection
    , noticeSection
    , noticePrinter
    , emptySection
    , keyHint
    , keyHintText
    , truncateVisible
    ) where

--------------------------------------------------------------------------------
import Ansiform

import Ansido.Domain
import Ansido.Ui.Theme

-- | Severity of a message shown above the screen body.
data NoticeKind = NoticeInfo | NoticeError
    deriving (Eq, Show)

-- | A short message with a severity, shown below the screen body.
data Notice = Notice
    { noticeKind :: NoticeKind
    , noticeText :: String
    }
    deriving (Eq, Show)

-- | Application header with a solid title bar, a blank line and a subtitle.
headerSection :: UiTheme -> String -> String -> Section
headerSection theme title subtitle =
    section
        [ printerSolidLineCenter
            0
            1
            (themeBar base)
            [blockSimple title (themeHeader base)]
        , printerEmpty 1
        , printerLineCenter 0 [blockSimple subtitle (themeSubtitle base)]
        , printerEmpty 1
        ]
  where
    base = uiBase theme

-- | Solid footer bar with the available shortcuts.
footerSection :: UiTheme -> [Block] -> Section
footerSection theme hints =
    sectionTop 1 [printerSolidLineLeft 0 1 (themeBar base) hints]
  where
    base = uiBase theme

-- | Section title used by the secondary screens.
titleSection :: UiTheme -> String -> Section
titleSection theme label =
    sectionTop 1 [printerLeft 1 (blockSimple label (themeTableHeader base))]
  where
    base = uiBase theme

-- | Category selector shown below the header.
categorySection :: UiTheme -> Maybe CategoryId -> [Category] -> Section
categorySection theme active categories =
    case categories of
        [] ->
            section
                [ printerLeft
                    1
                    (blockSimple "No categories yet." (themeMuted base))
                ]
        _ ->
            section
                [ printerLineLeft
                    1
                    (blockSimple "Categories:" (themeTableHeader base) : map categoryBlock categories)
                ]
  where
    base = uiBase theme
    categoryBlock category =
        let label = " " <> categoryNameText (categoryName category) <> " "
         in if Just (categoryId category) == active
                then blockSimple label (solid (themeBar base))
                else blockSimple label (themeMuted base)

-- | Message shown above the body of a screen.
noticeSection :: UiTheme -> Notice -> Section
noticeSection theme notice = section [noticePrinter theme notice]

-- | Printer for a single notice line.
noticePrinter :: UiTheme -> Notice -> Printer
noticePrinter theme notice =
    printerLeft 1 (blockCycle [(marker, style), (" " <> text, style)])
  where
    marker = case noticeKind notice of
        NoticeInfo -> "i"
        NoticeError -> "!"
    text = noticeText notice
    style = case noticeKind notice of
        NoticeInfo -> uiNoticeInfo theme
        NoticeError -> uiNoticeError theme

-- | Centered placeholder for empty screens.
emptySection :: UiTheme -> String -> Section
emptySection theme message =
    sectionBody
        1
        [printerCenter 0 (blockSimple message (themeMuted (uiBase theme)))]

-- | A shortcut such as @a add@.
keyHint :: UiTheme -> Char -> String -> Block
keyHint theme key label = keyHintText theme [key] label

-- | A shortcut with an arbitrary key label, such as @Enter@.
keyHintText :: UiTheme -> String -> String -> Block
keyHintText theme key label =
    blockCycle
        [ (key, uiSelected theme)
        , (" " <> label, themeFooter (uiBase theme))
        ]

-- | Truncates text to a visible width, appending an ellipsis when needed.
truncateVisible :: Int -> String -> String
truncateVisible limit text
    | textWidth text <= limit = text
    | limit <= 1 = takeVisible limit text
    | otherwise = takeVisible (limit - 1) text <> "…"

takeVisible :: Int -> String -> String
takeVisible limit = go 0
  where
    go _ [] = []
    go used (char : rest)
        | used + charWidth char > limit = []
        | otherwise = char : go (used + charWidth char) rest
