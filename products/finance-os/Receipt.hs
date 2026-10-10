{-
  Receipt.hs — Finance OS (SEIT product recreation)
  Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
  SPDX-License-Identifier: LicenseRef-SEIT-FSL-Donation-1.0

  Functional source, donation-gated runtime: you may read, share, and
  modify this source freely; running it requires a qualifying donation
  to the licensor. See LICENSE.txt for the full terms. No warranty.
-}
-- | The "third entry": a hash-chained receipt for every accepted posting.
--
-- receipt_0 = fnv1a64("")
-- receipt_n = fnv1a64(encode(receipt_{n-1}) <> encode(posting_n))
--
-- Only postings accepted by 'Ledger.post' are issued receipts; rejected
-- postings never enter the chain.
module Receipt
  ( Digest
  , digestHex
  , fnv1a64
  , Receipt (..)
  , issueReceipts
  ) where

import Data.Bits (shiftR, xor)
import Data.Word (Word8, Word64)
import Ledger (Account (..), Leg (..), Posting (..), Side (..))
import Text.Printf (printf)

-- | A 64-bit hash digest. 'Digest' is a newtype so hashes cannot be
-- confused with raw integers.
newtype Digest = Digest Word64
  deriving (Eq, Ord)

digestHex :: Digest -> String
digestHex (Digest w) = printf "%016x" w

-- | FNV-1a, 64-bit variant, written from the published definition:
-- h = offset_basis; for each byte: h = (h XOR byte) * prime.
-- offset_basis = 14695981039346656037, prime = 1099511628211.
-- This is a fast NON-cryptographic hash; the chain below gives
-- tamper-evidence (any change to a posting breaks all later receipts),
-- not cryptographic sealing. See README.
fnv1a64 :: [Word8] -> Word64
fnv1a64 = foldl' step 14695981039346656037
  where
    step :: Word64 -> Word8 -> Word64
    step h b = (h `xor` fromIntegral b) * 1099511628211

-- ---------------------------------------------------------------------------
-- Deterministic byte encoding (big-endian, length-prefixed). Two equal
-- postings always encode to identical bytes; two different postings
-- always encode differently, so the hash chain is unambiguous.
-- ---------------------------------------------------------------------------

encodeWord64 :: Word64 -> [Word8]
encodeWord64 w = [fromIntegral (w `shiftR` s) | s <- [56, 48 .. 0]]

encodeInteger :: Integer -> [Word8]
encodeInteger n
  | n <= 0    = [0]
  | otherwise = fromIntegral (length bytes) : bytes
  where
    bytes :: [Word8]
    bytes = go n []
    go :: Integer -> [Word8] -> [Word8]
    go 0 acc = acc
    go x acc = go (x `div` 256) (fromIntegral (x `mod` 256) : acc)

-- | ASCII/byte memo: length-prefixed bytes.
encodeString :: String -> [Word8]
encodeString s = fromIntegral (length s) : map (fromIntegral . fromEnum) s

encodeAccount :: Account -> [Word8]
encodeAccount a = [fromIntegral (fromEnum a + 1)]

encodeSide :: Side -> [Word8]
encodeSide Debit  = [0]
encodeSide Credit = [1]

encodeLeg :: Leg -> [Word8]
encodeLeg l =
  encodeAccount (legAccount l)
    ++ encodeSide (legSide l)
    ++ encodeInteger (legAmount l)

encodePosting :: Posting -> [Word8]
encodePosting p = encodeString (postingMemo p) ++ concatMap encodeLeg (postingLegs p)

-- | A sealed receipt: the posting plus its position in the chain.
data Receipt = Receipt
  { receiptIndex   :: Int
  , receiptDigest  :: Digest
  , receiptPosting :: Posting
  }

-- | Issue a receipt for each posting in order. The chain starts from a
-- genesis digest (FNV-1a of the empty input).
issueReceipts :: [Posting] -> [Receipt]
issueReceipts = go genesis 0
  where
    genesis :: Digest
    genesis = Digest (fnv1a64 [])
    go :: Digest -> Int -> [Posting] -> [Receipt]
    go _    _ []     = []
    go prev i (p:ps) =
      let Digest prevW = prev
          d = Digest (fnv1a64 (encodeWord64 prevW ++ encodePosting p))
          r = Receipt i d p
      in r : go d (i + 1) ps
