{-|
Module      : Botan.Bindings.Ed25519
Description : Algorithm specific key operations: Ed25519
Copyright   : (c) Leo D, 2023
License     : BSD-3-Clause
Maintainer  : leo@apotheca.io
Stability   : experimental
Portability : POSIX
-}

{-# LANGUAGE CApiFFI #-}

module Botan.Bindings.PubKey.Ed25519 where

import Botan.Bindings.Prelude
import Botan.Bindings.PubKey

foreign import capi safe "botan/ffi.h botan_privkey_load_ed25519"
    botan_privkey_load_ed25519
        :: Ptr BotanPrivKey -- ^ @key@
        -> ConstPtr Word8   -- ^ @privkey[32]@
        -> IO CInt

foreign import capi safe "botan/ffi.h botan_pubkey_load_ed25519"
    botan_pubkey_load_ed25519
        :: Ptr BotanPubKey  -- ^ @key@
        -> ConstPtr Word8   -- ^ @pubkey[32]@
        -> IO CInt

foreign import capi safe "botan/ffi.h botan_privkey_ed25519_get_privkey"
    botan_privkey_ed25519_get_privkey
        :: BotanPrivKey     -- ^ @key@
        -> Ptr Word8        -- ^ @output[64]@
        -> IO CInt

foreign import capi safe "botan/ffi.h botan_pubkey_ed25519_get_pubkey"
    botan_pubkey_ed25519_get_pubkey
        :: BotanPubKey      -- ^ @key@
        -> Ptr Word8        -- ^ @pubkey[32]@
        -> IO CInt
