module Main (main) where

--------------------------------------------------------------------------------
import System.IO (hSetEncoding, stderr, stdin, stdout, utf8)

import Ansido.App.Run (runApp)

-- | Standard handles use UTF-8 so the arrows, the backspace icon and any
-- non-ASCII task text render on every platform, including the Windows console.
main :: IO ()
main = do
    hSetEncoding stdin utf8
    hSetEncoding stdout utf8
    hSetEncoding stderr utf8
    runApp
