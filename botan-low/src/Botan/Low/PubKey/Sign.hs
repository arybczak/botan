{-|
Module      : Botan.Low.Sign
Description : Signature Generation
Copyright   : (c) Leo D, 2023
License     : BSD-3-Clause
Maintainer  : leo@apotheca.io
Stability   : experimental
Portability : POSIX
-}

module Botan.Low.PubKey.Sign where

import qualified Data.ByteString as ByteString

import Botan.Bindings.PubKey.Sign

import Botan.Low.Error
import Botan.Low.Make
import Botan.Low.Prelude
import Botan.Low.RNG
import Botan.Low.PubKey

-- /*
-- * Signature Generation
-- */

newtype SignCtx = MkSignCtx { getSignForeignPtr :: ForeignPtr SignStruct }

withSignPtr :: SignCtx -> (SignPtr -> IO a) -> IO a
withSignPtr = withForeignPtr . getSignForeignPtr

-- TODO: Rename SignAlgoParams / SigningParams
type SignAlgoName = ByteString

pattern SigningNoFlags :: SigningFlags
pattern SigningNoFlags = BOTAN_PUBKEY_SIGNING_FLAGS_NONE
pattern SigningDERFormatSignature = BOTAN_PUBKEY_DER_FORMAT_SIGNATURE

signCreate :: PrivKey -> SignAlgoName -> SigningFlags -> IO SignCtx
signCreate sk algo flags = alloca $ \ outPtr -> do
    withPrivKeyPtr sk $ \ skPtr -> do
        asCString algo $ \ algoPtr -> do
            throwBotanIfNegative_ $ botan_pk_op_sign_create outPtr skPtr algoPtr flags
            out <- peek outPtr
            foreignPtr <- newForeignPtr botan_pk_op_sign_destroy out
            return $ MkSignCtx foreignPtr

withSignCreate :: PrivKey -> SignAlgoName -> SigningFlags -> (SignCtx -> IO a) -> IO a
withSignCreate = mkWithTemp3 signCreate signDestroy

signDestroy :: SignCtx -> IO ()
signDestroy sign = finalizeForeignPtr (getSignForeignPtr sign)

signOutputLength :: SignCtx -> IO Int
signOutputLength = mkGetSize withSignPtr botan_pk_op_sign_output_length

signUpdate :: SignCtx -> ByteString -> IO ()
signUpdate = mkSetBytesLen withSignPtr botan_pk_op_sign_update

-- TODO: Signature type
signFinish :: SignCtx -> RNG -> IO ByteString
signFinish sign rng = withSignPtr sign $ \ signPtr -> do
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

-- /**
-- * Signature Scheme Utility Functions
-- */

-- TODO: botan_pkcs_hash_id
