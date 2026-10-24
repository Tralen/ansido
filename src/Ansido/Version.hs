-- | Application version, single sourced from the Cabal package file.
module Ansido.Version
    ( versionText
    ) where

--------------------------------------------------------------------------------
import Data.Version (showVersion)

import qualified Paths_ansido

-- | Version shown in the interface.
versionText :: String
versionText = showVersion Paths_ansido.version
