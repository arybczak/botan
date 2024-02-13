{-|
Module      : Botan.Low.PubKey.Sign
Description : Signature Generation
Copyright   : (c) Leo D, 2023
License     : BSD-3-Clause
Maintainer  : leo@apotheca.io
Stability   : experimental
Portability : POSIX
-}

module Botan.Low.PubKey.Sign
(

-- * Public key signatures
  Sign(..)
, SigningFlags(..)
, pattern StandardFormatSignature
, pattern DERFormatSignature
, withSign
, signCreate
, signDestroy
, signOutputLength
, signUpdate
, signFinish

) where

import qualified Data.ByteString as ByteString

import Botan.Bindings.PubKey.Sign

import Botan.Low.Error
import Botan.Low.Make
import Botan.Low.Prelude
import Botan.Low.RNG
import Botan.Low.PubKey
import Botan.Low.Remake

-- /*
-- * Signature Generation
-- */

newtype Sign = MkSign { getSignForeignPtr :: ForeignPtr BotanPKOpSignStruct }

newSign      :: BotanPKOpSign -> IO Sign
withSign     :: Sign -> (BotanPKOpSign -> IO a) -> IO a
signDestroy  :: Sign -> IO ()
createSign   :: (Ptr BotanPKOpSign -> IO CInt) -> IO Sign
(newSign, withSign, signDestroy, createSign, _)
    = mkBindings
        MkBotanPKOpSign runBotanPKOpSign
        MkSign getSignForeignPtr
        botan_pk_op_sign_destroy

-- TODO: Rename SignAlgoParams / SigningParams
type SignAlgoName = ByteString

type SigningFlags = Word32

pattern StandardFormatSignature   -- ^ Not an actual flags
    ,   DERFormatSignature
    ::  SigningFlags
pattern StandardFormatSignature = BOTAN_PUBKEY_STD_FORMAT_SIGNATURE
pattern DERFormatSignature = BOTAN_PUBKEY_DER_FORMAT_SIGNATURE

signCreate
    :: PrivKey      -- ^ @key@
    -> EMSAName     -- ^ @hash_and_padding@
    -> SigningFlags -- ^ @flags@
    -> IO Sign      -- ^ @op@
signCreate sk algo flags = withPrivKey sk $ \ skPtr -> do
    asCString algo $ \ algoPtr -> do
        createSign $ \ out -> botan_pk_op_sign_create
            out
            skPtr
            (ConstPtr algoPtr)
            flags

-- WARNING: withFooInit-style limited lifetime functions moved to high-level botan
withSignCreate :: PrivKey -> EMSAName -> SigningFlags -> (Sign -> IO a) -> IO a
withSignCreate = mkWithTemp3 signCreate signDestroy

signOutputLength
    :: Sign     -- ^ @op@
    -> IO Int   -- ^ @olen@
signOutputLength = mkGetSize withSign botan_pk_op_sign_output_length

signUpdate
    :: Sign         -- ^ @op@
    -> ByteString   -- ^ @in[]@
    -> IO ()
-- signUpdate = mkSetBytesLen withSign botan_pk_op_sign_update
signUpdate = mkWithObjectSetterCBytesLen withSign botan_pk_op_sign_update

-- TODO: Signature type
-- NOTE: This function is still highly suspect
signFinish
    :: Sign             -- ^ @op@
    -> RNG              -- ^ @rng@
    -> IO ByteString    -- ^ @sig[]@
signFinish sign rng = withSign sign $ \ signPtr -> do
    withRNG rng $ \ botanRNG -> do
        -- NOTE: Investigation into DER format shows lots of trailing nulls that may need to be trimmed
        --  using the output of szPtr if sz is just an upper-bound estimate
        -- sz <- signOutputLength sign
        -- allocBytes sz $ \ sigPtr -> do
        --     alloca $ \ szPtr -> do
        --         poke szPtr (fromIntegral sz)
        --         throwBotanIfNegative_ $ botan_pk_op_sign_finish signPtr botanRNG sigPtr szPtr
        -- NOTE: This doesn't work, I think the output length poke is necessary
        -- allocBytesQuerying $ \ sigPtr szPtr -> do
        --     botan_pk_op_sign_finish signPtr botanRNG sigPtr szPtr
        -- NOTE: Trying combo, this should be packaged as allocBytesUpperBound or something
        --  We get an upper bound, allocate at least that many, poke the size, perform the
        --  op, read the actual size, and trim.
        sz <- signOutputLength sign
        (sz',bytes) <- allocBytesWith sz $ \ sigPtr -> do
            alloca $ \ szPtr -> do
                poke szPtr (fromIntegral sz)
                throwBotanIfNegative_ $ botan_pk_op_sign_finish signPtr botanRNG sigPtr szPtr
                peek szPtr
        return $!! ByteString.take (fromIntegral sz') bytes
{-# WARNING signFinish "Depending on the algorithm, signatures produced using StandardFormatSignature may have trailing null bytes." #-}

-- /**
-- * Signature Scheme Utility Functions
-- */

-- TODO: botan_pkcs_hash_id
