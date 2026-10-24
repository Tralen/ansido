-- | The shared visual language of the application.
--
-- A single 'UiTheme' is passed to every component so headers, footers,
-- boards and messages keep the same behavior and colors.
module Ansido.Ui.Theme
    ( UiTheme (..)
    , defaultUiTheme
    , statusStyle
    ) where

--------------------------------------------------------------------------------
import Ansiform

import Ansido.Domain

-- | Base theme plus the semantic styles used by the application.
data UiTheme = UiTheme
    { uiBase :: Theme
    , uiTodo :: Style
    , uiDoing :: Style
    , uiDone :: Style
    , uiSelected :: Style
    , uiNoticeInfo :: Style
    , uiNoticeError :: Style
    }

-- | The default theme, built from Ansiform primitives.
defaultUiTheme :: UiTheme
defaultUiTheme =
    UiTheme
        { uiBase =
            Theme
                { themeHeader = bold white'
                , themeSubtitle = normal cyan'
                , themeFooter = normal white'
                , themeAccent = bold cyan'
                , themeDanger = bold red'
                , themeMuted = italic white
                , themeRule = normal black'
                , themeBar = blue
                , themeTableHeader = bold yellow'
                , themeTableBody = normal white'
                }
        , uiTodo = bold red'
        , uiDoing = bold cyan'
        , uiDone = bold green'
        , uiSelected = bold white'
        , uiNoticeInfo = normal cyan'
        , uiNoticeError = bold red'
        }

-- | Style of a status label.
statusStyle :: UiTheme -> Status -> Style
statusStyle theme status =
    case status of
        Todo -> uiTodo theme
        Doing -> uiDoing theme
        Done -> uiDone theme
