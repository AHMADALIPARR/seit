{-
  Main.hs — Quantum Governance Bridge (SEIT product recreation)
  Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
  SPDX-License-Identifier: LicenseRef-SEIT-FSL-Donation-1.0

  Functional source, donation-gated runtime: you may read, share, and
  modify this source freely; running it requires a qualifying donation
  to the licensor. See LICENSE.txt for the full terms. No warranty.
-}
-- Quantum Governance Bridge
-- A compact, working recreation of the SEIT "Quantum Governance Bridge"
-- four-layer sovereign decision pipeline, written fresh for this product.
--
-- Layer 1: entropy drawn from /dev/urandom (system entropy).
-- Layer 2: one-shot consumption modeled with a phantom-typed token that is
--   threaded through the pipeline exactly once. This is a MODEL, not
--   compiler-enforced linear typing (real linearity needs the LinearTypes
--   extension; see README).
-- Layer 3: four watchtowers (East/Air, South/Fire, West/Water, North/Earth)
--   vote as pure predicates; METATRON-style weighted majority certifies.
-- Layer 4: the certified decision is sealed into a hash-chained,
--   append-only WORM receipt (FNV-1a-64, implemented by hand below).

module Main (main) where

import Data.Bits (xor, shiftR, (.&.))
import qualified Data.ByteString as BS
import Data.Char (ord)
import Data.List (isPrefixOf)
import Data.Word (Word8, Word64)
import Numeric (showHex, readHex)
import System.Directory (doesFileExist)
import System.IO (IOMode (ReadMode), openBinaryFile, hClose)

-----------------------------------------------------------------------------
-- Layer 1: entropy source
-----------------------------------------------------------------------------

entropyByteCount :: Int
entropyByteCount = 32

-----------------------------------------------------------------------------

data EntropySample = EntropySample
  { esId    :: Word64   -- sample id: first 8 bytes as big-endian Word64
  , esBytes :: [Word8]  -- 32 raw bytes from /dev/urandom
  }

bytesToWord64 :: [Word8] -> Word64
bytesToWord64 = foldl (\acc b -> acc * 256 + fromIntegral b) 0

sampleEntropy :: IO EntropySample
sampleEntropy = do
  h <- openBinaryFile "/dev/urandom" ReadMode
  raw <- BS.hGet h entropyByteCount
  hClose h
  let bs = BS.unpack raw
  return (EntropySample (bytesToWord64 (take 8 bs)) bs)

-----------------------------------------------------------------------------
-- Layer 2: one-shot consumption (modeled, NOT compiler-enforced)
-----------------------------------------------------------------------------

data Fresh
data Consumed

-- A phantom-typed token: the type tracks whether the sample is fresh or
-- already consumed. The pipeline binds each token once and never reuses
-- the Fresh value afterwards; the Consumed token is only good for audit.
newtype Token a = Token { tokenId :: Word64 }

-- Four parity bits derived from the sample's quadrants: the "decision
-- material" the watchtowers vote on.
type DecisionBits = [Bool]

mint :: EntropySample -> Token Fresh
mint s = Token (esId s)

data ConsumptionProof = ConsumptionProof
  { cpTokenId  :: Word64
  , cpBytesIn  :: Int
  , cpOneShot  :: String
  }

consume :: Token Fresh -> EntropySample -> (Token Consumed, ConsumptionProof, DecisionBits)
consume (Token tid) s =
  let proof = ConsumptionProof
        { cpTokenId = tid
        , cpBytesIn = length (esBytes s)
        , cpOneShot = "Fresh handle consumed exactly once; type state moved Fresh -> Consumed"
        }
      bits = bitsOf s
  in (Token tid, proof, bits)

bitsOf :: EntropySample -> DecisionBits
bitsOf s = map evenParity [q1, q2, q3, q4]
  where
    bs :: [Word8]
    bs = esBytes s
    (q1, r1) = splitAt 8 bs
    (q2, r2) = splitAt 8 r1
    (q3, q4) = splitAt 8 r2
    evenParity :: [Word8] -> Bool
    evenParity qs = even (sum (map fromIntegral qs :: [Int]))

-----------------------------------------------------------------------------
-- Layer 3: four watchtowers + METATRON-style weighted certification
-----------------------------------------------------------------------------

data Vote = Vote
  { vTower   :: String
  , vElement :: String
  , vWeight  :: Int
  , vApprove :: Bool
  , vReason  :: String
  }

type Ballot = (EntropySample, DecisionBits)

-- Weights (documented in README): Air 3, Fire 2, Water 2, Earth 1.
-- Certification rule: strict weighted majority, i.e. approvals must weigh
-- MORE than half of the total (threshold = floor(total/2) + 1 = 5 of 8).
watchtowers :: [Ballot -> Vote]
watchtowers = [eastAir, southFire, westWater, northEarth]

eastAir :: Ballot -> Vote
eastAir (_, bits) =
  let ok = and bits
  in Vote "East" "Air" 3 ok
       ("quadrant parities " ++ show bits ++ if ok then " -- all even" else " -- mixed")

southFire :: Ballot -> Vote
southFire (s, _) =
  let b = case esBytes s of
            (x : _) -> x
            []      -> 0
      ok = b >= 128
  in Vote "South" "Fire" 2 ok
       ("lead byte 0x" ++ hexByte b ++ if ok then " -- spark lit" else " -- spark dark")

westWater :: Ballot -> Vote
westWater (s, _) =
  let total = sum (map fromIntegral (esBytes s) :: [Int]) `mod` 256
      ok = total >= 128
  in Vote "West" "Water" 2 ok
       ("byte-sum mod 256 = " ++ show total ++ if ok then " -- deep water" else " -- shallow")

northEarth :: Ballot -> Vote
northEarth (s, _) =
  let b = case reverse (esBytes s) of
            (x : _) -> x
            []      -> 1
      ok = even b
  in Vote "North" "Earth" 1 ok
       ("trail byte 0x" ++ hexByte b ++ if ok then " -- grounded" else " -- ungrounded")

data Verdict = CertifiedApprove | CertifiedReject deriving (Show)

data Certification = Certification
  { cVerdict   :: Verdict
  , cFor       :: Int
  , cTotal     :: Int
  , cThreshold :: Int
  }

certify :: [Vote] -> Certification
certify vs =
  let for   = sum [vWeight v | v <- vs, vApprove v]
      total = sum (map vWeight vs)
      thr   = total `div` 2 + 1
  in Certification (if for >= thr then CertifiedApprove else CertifiedReject) for total thr

-----------------------------------------------------------------------------
-- Layer 4: WORM receipt (hash-chained, append-only)
-----------------------------------------------------------------------------

-- FNV-1a 64-bit, implemented by hand with the standard constants.
-- 64-bit offset basis: 14695981039346656037, prime: 1099511628211.
fnv1a64 :: [Word8] -> Word64
fnv1a64 = foldl step fnvOffset
  where
    fnvOffset :: Word64
    fnvOffset = 14695981039346656037
    fnvPrime :: Word64
    fnvPrime = 1099511628211
    step :: Word64 -> Word8 -> Word64
    step h b = (h `xor` fromIntegral b) * fnvPrime

word64Bytes :: Word64 -> [Word8]
word64Bytes w = [fromIntegral (shiftR w (8 * i)) .&. 0xff | i <- [7, 6 .. 0]]

stringBytes :: String -> [Word8]
stringBytes = map (fromIntegral . ord)

receiptLogPath :: String
receiptLogPath = "receipts.log"

-- Previous receipt hash for the chain: hash field of the last log line,
-- or 0 (genesis) when the log does not exist yet.
prevHash :: IO Word64
prevHash = do
  exists <- doesFileExist receiptLogPath
  if exists
    then do
      content <- readFile receiptLogPath
      let h = parseLast (lines content)
      h `seq` return h
    else return 0
  where
    parseLast :: [String] -> Word64
    parseLast ls = case reverse ls of
      []    -> 0
      (l:_) -> parseHashLine l
    parseHashLine :: String -> Word64
    parseHashLine l = case words l of
      (w : _) | "hash=" `isPrefixOf` w -> readHexWord (drop 5 w)
      _ -> 0
    readHexWord :: String -> Word64
    readHexWord s = case readHex s of
      [(v, "")] -> v
      _         -> 0

data Receipt = Receipt
  { rPrev    :: Word64
  , rVerdict :: Verdict
  , rHash    :: Word64
  , rBody    :: String
  }

seal :: Word64 -> Word64 -> [Vote] -> Certification -> ConsumptionProof -> IO Receipt
seal prev sampleId votes cert proof = do
  let voteStr = concatMap (\v -> vTower v ++ ":" ++ (if vApprove v then "A" else "R")
                             ++ "(" ++ show (vWeight v) ++ ") ") votes
      body = "prev=" ++ hex64 prev
          ++ " | entropy=" ++ hex64 sampleId
          ++ " | consumed=" ++ hex64 (cpTokenId proof)
          ++ " | verdict=" ++ show (cVerdict cert)
          ++ " | votes=" ++ show (cFor cert) ++ "/" ++ show (cTotal cert)
          ++ " | tower=" ++ voteStr
      h = fnv1a64 (word64Bytes prev ++ stringBytes body)
      receipt = Receipt prev (cVerdict cert) h body
  appendFile receiptLogPath ("hash=" ++ hex64 h ++ " " ++ body ++ "\n")
  return receipt

-----------------------------------------------------------------------------
-- Formatting helpers
-----------------------------------------------------------------------------

hex64 :: Word64 -> String
hex64 w = let s = showHex w "" in replicate (16 - length s) '0' ++ s

hexByte :: Word8 -> String
hexByte b = let s = showHex b "" in replicate (2 - length s) '0' ++ s

voteLine :: Vote -> String
voteLine v =
  "  " ++ vTower v ++ "/" ++ vElement v
  ++ "  (w=" ++ show (vWeight v) ++ ") : "
  ++ (if vApprove v then "APPROVE" else "DENY   ")
  ++ "  -- " ++ vReason v

-----------------------------------------------------------------------------
-- Demo: one decision end-to-end through all four layers
-----------------------------------------------------------------------------

main :: IO ()
main = do
  -- Layer 1: entropy
  sample <- sampleEntropy
  -- Layer 2: one-shot consumption (the Fresh token is used exactly here)
  let fresh = mint sample
      (consumed, proof, bits) = consume fresh sample
  -- Layer 3: watchtower vote + certification
  let votes = map ($ (sample, bits)) watchtowers
      cert  = certify votes
  -- Layer 4: seal into the hash-chained WORM log
  prev <- prevHash
  receipt <- seal prev (esId sample) votes cert proof

  putStrLn "=== QUANTUM GOVERNANCE BRIDGE: DECISION RECEIPT ==="
  putStrLn ""
  putStrLn "Layer 1 -- Entropy source (/dev/urandom):"
  putStrLn ("  sample id : 0x" ++ hex64 (esId sample))
  putStrLn ("  bytes     : " ++ show (length (esBytes sample)))
  putStrLn ""
  putStrLn "Layer 2 -- One-shot consumption (modeled, not compiler-enforced):"
  putStrLn ("  token     : 0x" ++ hex64 (tokenId consumed) ++ " Fresh -> Consumed")
  putStrLn ("  proof     : " ++ cpOneShot proof ++ " (" ++ show (cpBytesIn proof) ++ " bytes)")
  putStrLn ""
  putStrLn "Layer 3 -- Four watchtowers (weights Air 3 / Fire 2 / Water 2 / Earth 1; threshold 5/8):"
  mapM_ (putStrLn . voteLine) votes
  putStrLn ("  certification : " ++ show (cVerdict cert)
          ++ " (" ++ show (cFor cert) ++ "/" ++ show (cTotal cert) ++ " weight,"
          ++ " threshold " ++ show (cThreshold cert) ++ ")")
  putStrLn ""
  putStrLn "Layer 4 -- WORM receipt (FNV-1a-64 hash chain, appended to receipts.log):"
  putStrLn ("  prev hash : 0x" ++ hex64 (rPrev receipt))
  putStrLn ("  verdict   : " ++ show (rVerdict receipt))
  putStrLn ("  receipt   : 0x" ++ hex64 (rHash receipt))
  putStrLn ("  body      : " ++ rBody receipt)
