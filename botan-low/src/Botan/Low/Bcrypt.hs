{-|
Module      : Botan.Low.Bcrypt
Description : Bcrypt password hashing
Copyright   : (c) Leo D, 2023
License     : BSD-3-Clause
Maintainer  : leo@apotheca.io
Stability   : experimental
Portability : POSIX

Generate and validate Bcrypt password hashes
-}

module Botan.Low.Bcrypt where

import qualified Data.ByteString as ByteString

import Botan.Bindings.Bcrypt

import Botan.Low.Error
import Botan.Low.Make
import Botan.Low.Prelude
import Botan.Low.RNG

import Data.ByteString.Internal as ByteString

-- NOTE: botan bcrypt does not take the salt as an input
--  Instead it uses a random generator to choose a random salt every time

type BcryptWorkFactor = Int

pattern BcryptFast
    ,   BcryptGood
    ,   BcryptStrong
    ::  BcryptWorkFactor

pattern BcryptFast    = BOTAN_BCRYPT_WORK_FACTOR_FAST
pattern BcryptGood    = BOTAN_BCRYPT_WORK_FACTOR_GOOD
pattern BcryptStrong  = BOTAN_BCRYPT_WORK_FACTOR_STRONG

-- |Create a password hash using Bcrypt
--
--  Output is formatted bcrypt $2a$...
bcryptGenerate
    :: ByteString       -- ^ The password
    -> RNG              -- ^ A random number generator
    -> BcryptWorkFactor -- ^ A work factor to slow down guessing attacks (a value of 12 to 16 is probably fine).
    -> IO ByteString
bcryptGenerate password rng factor = asCString password $ \ passwordPtr -> do
   withRNG rng $ \ botanRNG -> do
        alloca $ \ szPtr -> do
            -- NOTE: bcrypt max pass size should be < 72 in general, we'll
            -- do 80 for safety
            poke szPtr 80
            allocaBytes 80 $ \ outPtr -> do
                throwBotanIfNegative_ $ botan_bcrypt_generate
                    outPtr
                    szPtr
                    (ConstPtr passwordPtr)
                    botanRNG
                    (fromIntegral factor)
                    0   -- "@param flags should be 0 in current API revision, all other uses are reserved"
                ByteString.packCString (castPtr outPtr)

-- |Check a previously created password hash
--
--  Returns True iff this password/hash combination is valid,
--  False if the combination is not valid (but otherwise well formed),
--  and otherwise throws an exception on error
--
-- TODO: Maybe rename bcryptValidate
bcryptIsValid
    :: ByteString   -- ^ The password to check against
    -> ByteString   -- ^ The stored hash to check against
    -> IO Bool
bcryptIsValid password hash = asCString password $ \ passwordPtr -> do
    asCString hash $ \ hashPtr -> do
        throwBotanCatchingSuccess $ botan_bcrypt_is_valid (ConstPtr passwordPtr) (ConstPtr hashPtr)
