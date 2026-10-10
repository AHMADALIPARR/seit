{-
  Sha256.hs — Sovereign Mesh (SEIT product recreation)
  Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
  SPDX-License-Identifier: LicenseRef-SEIT-FSL-Donation-1.0

  Functional source, donation-gated runtime: you may read, share, and
  modify this source freely; running it requires a qualifying donation
  to the licensor. See LICENSE.txt for the full terms. No warranty.
-}
-- | Minimal, self-contained SHA-256 implementation (FIPS 180-4).
-- Written fresh for this project. Used two ways here:
--   1. as a keyed hash (secret || message) standing in for agent signatures
--      (it is NOT Ed25519; see README), and
--   2. as the WORM log's hash chain.
module Sha256 (sha256Hex) where

import Data.Bits (complement, rotateR, shiftR, xor, (.&.))
import Data.Char (ord)
import Data.Word (Word8, Word32, Word64)
import Numeric (showHex)

-- | SHA-256 of a String, rendered as 64 lowercase hex characters.
sha256Hex :: String -> String
sha256Hex = concatMap byteHex . sha256Bytes . map (fromIntegral . ord)

byteHex :: Word8 -> String
byteHex b =
  let s = showHex b ""
   in if length s == 1 then '0' : s else s

chunksOf :: Int -> [a] -> [[a]]
chunksOf _ [] = []
chunksOf n xs = take n xs : chunksOf n (drop n xs)

word32BE :: Word32 -> [Word8]
word32BE w = map (\s -> fromIntegral (shiftR w s)) [24, 16, 8, 0]

word64BE :: Word64 -> [Word8]
word64BE w = map (\s -> fromIntegral (shiftR w s)) [56, 48, 40, 32, 24, 16, 8, 0]

bytesToWord32 :: [Word8] -> Word32
bytesToWord32 = foldl' (\acc x -> acc * 256 + fromIntegral x) 0

-- Round constants.
kConsts :: [Word32]
kConsts =
  [ 0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1
  , 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3
  , 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786
  , 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da
  , 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147
  , 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13
  , 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b
  , 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070
  , 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a
  , 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208
  , 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ]

type HState = (Word32, Word32, Word32, Word32, Word32, Word32, Word32, Word32)

initH :: HState
initH =
  ( 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
  , 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
  )

ch :: Word32 -> Word32 -> Word32 -> Word32
ch x y z = (x .&. y) `xor` (complement x .&. z)

maj :: Word32 -> Word32 -> Word32 -> Word32
maj x y z = (x .&. y) `xor` (x .&. z) `xor` (y .&. z)

bigS0 :: Word32 -> Word32
bigS0 x = rotateR x 2 `xor` rotateR x 13 `xor` rotateR x 22

bigS1 :: Word32 -> Word32
bigS1 x = rotateR x 6 `xor` rotateR x 11 `xor` rotateR x 25

smallS0 :: Word32 -> Word32
smallS0 x = rotateR x 7 `xor` rotateR x 18 `xor` shiftR x 3

smallS1 :: Word32 -> Word32
smallS1 x = rotateR x 17 `xor` rotateR x 19 `xor` shiftR x 10

compress :: HState -> (Word32, Word32) -> HState
compress (a, b, c, d, e, f, g, h) (wi, ki) =
  let t1 = h + bigS1 e + ch e f g + ki + wi
      t2 = bigS0 a + maj a b c
   in (t1 + t2, a, b, c, d + t1, e, f, g)

processBlock :: HState -> [Word8] -> HState
processBlock (a, b, c, d, e, f, g, h) blk =
  let wInit = map bytesToWord32 (chunksOf 4 blk)
      w =
        wInit
          ++ [ smallS1 (w !! (i - 2)) + w !! (i - 7)
                 + smallS0 (w !! (i - 15))
                 + w !! (i - 16)
             | i <- [16 .. 63]
             ]
      (a1, b1, c1, d1, e1, f1, g1, h1) =
        foldl' compress (a, b, c, d, e, f, g, h) (zip w kConsts)
   in (a + a1, b + b1, c + c1, d + d1, e + e1, f + f1, g + g1, h + h1)

sha256Bytes :: [Word8] -> [Word8]
sha256Bytes input =
  let bitLen = fromIntegral (length input) * 8 :: Word64
      padLen = (55 - length input) `mod` 64
      padded = input ++ [0x80] ++ replicate padLen 0x00 ++ word64BE bitLen
      blocks = chunksOf 64 padded
      (h0, h1, h2, h3, h4, h5, h6, h7) = foldl' processBlock initH blocks
   in concatMap word32BE [h0, h1, h2, h3, h4, h5, h6, h7]
