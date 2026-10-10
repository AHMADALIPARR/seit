{-
  Main.hs — ERE v1.0 (SEIT product recreation)
  Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
  SPDX-License-Identifier: LicenseRef-SEIT-FSL-Donation-1.0

  Functional source, donation-gated runtime: you may read, share, and
  modify this source freely; running it requires a qualifying donation
  to the licensor. See LICENSE.txt for the full terms. No warranty.
-}
{- |
ERE v1.0 — Enochian Reconstruction Engine (five-pass core recreation).

A token stream (each token tagged with a script) is checked across five
language passes.  Each pass is a PURE predicate over the token stream.
METATRON certifies the input only when all five passes agree (all True);
otherwise it is REJECTED, naming the failed pass(es).

Script alphabets are kept abstract as character sets (see README for the
exact simplification).  This is a constraint-checking demo, not a
decipherment of any ancient script.
-}
module Main (main) where

import Data.List (intercalate)
import System.IO (hSetEncoding, stdout, utf8)

-- ---------------------------------------------------------------------------
-- Scripts and tokens
-- ---------------------------------------------------------------------------

-- | The five scripts of the five-pass core.
data Script
  = Enochian
  | Latin
  | Hebrew
  | Arabic
  | Aramaic
  deriving (Eq, Show)

-- | A token is a text plus the script it is tagged with.
data Token = Token
  { tokenScript :: Script
  , tokenText   :: String
  } deriving (Eq, Show)

-- ---------------------------------------------------------------------------
-- Codepoint predicates (abstract alphabets, documented in README)
-- ---------------------------------------------------------------------------

inRange :: Char -> Char -> Char -> Bool
inRange lo hi c = c >= lo && c <= hi

isLatinGlyph :: Char -> Bool
isLatinGlyph c = inRange 'a' 'z' c || inRange 'A' 'Z' c

isHebrewGlyph :: Char -> Bool
isHebrewGlyph c = inRange '\x0590' '\x05FF' c

isArabicGlyph :: Char -> Bool
isArabicGlyph c = inRange '\x0600' '\x06FF' c

isAramaicGlyph :: Char -> Bool
isAramaicGlyph c = inRange '\x10840' '\x1085F' c

-- | Enochian glyphs stand in as the Unicode Private Use Area U+E000–U+E0FF
-- (documented simplification; see README).
isEnochianGlyph :: Char -> Bool
isEnochianGlyph c = inRange '\xE000' '\xE0FF' c

-- | The Aramaic root layer predicate: a consonantal root of exactly three
-- Imperial Aramaic glyphs (triliteral root).
isTriliteralRoot :: String -> Bool
isTriliteralRoot t = length t == 3 && all isAramaicGlyph t

-- ---------------------------------------------------------------------------
-- The five passes
-- ---------------------------------------------------------------------------

-- | A language pass: a name plus a pure predicate over the token stream.
data Pass = Pass
  { passName  :: String
  , passCheck :: [Token] -> Bool
  }

-- | A pass inspects only the tokens tagged with its own script, and every
-- such token must satisfy that script's text predicate.  A script with no
-- tokens in the stream passes vacuously (documented simplification).
forScript :: Script -> (String -> Bool) -> [Token] -> Bool
forScript s ok toks =
  all ok [tokenText t | t <- toks, tokenScript t == s]

passes :: [Pass]
passes =
  [ Pass "Enochian" (forScript Enochian (all isEnochianGlyph))
  , Pass "Latin"    (forScript Latin    (all isLatinGlyph))
  , Pass "Hebrew"   (forScript Hebrew   (all isHebrewGlyph))
  , Pass "Arabic"   (forScript Arabic   (all isArabicGlyph))
  , Pass "Aramaic"  (forScript Aramaic  isTriliteralRoot)
  ]

-- ---------------------------------------------------------------------------
-- METATRON: the certifier
-- ---------------------------------------------------------------------------

-- | CERTIFIED when all five passes agree; otherwise REJECTED, naming every
-- failed pass.
data Verdict = Certified | Rejected [String]
  deriving (Eq, Show)

metatron :: [Token] -> Verdict
metatron toks = case failed of
  [] -> Certified
  fs -> Rejected fs
  where
    failed :: [String]
    failed = [passName p | p <- passes, not (passCheck p toks)]

-- ---------------------------------------------------------------------------
-- Demo streams (non-interactive)
-- ---------------------------------------------------------------------------

-- | Input A: one valid token per script — all five passes agree.
certifiedInput :: [Token]
certifiedInput =
  [ Token Latin    "Lux"
  , Token Hebrew   "\x05D0\x05D1\x05D2"
  , Token Arabic   "\x0627\x0644\x0646"
  , Token Aramaic  "\x10840\x10841\x10842"
  , Token Enochian "\xE000\xE001\xE002"
  ]

-- | Input B: a Latin-tagged token carries a digit — the Latin pass fails.
latinBreakInput :: [Token]
latinBreakInput =
  [ Token Latin    "Lux4"
  , Token Hebrew   "\x05D0\x05D1\x05D2"
  , Token Arabic   "\x0627\x0644\x0646"
  , Token Aramaic  "\x10840\x10841\x10842"
  , Token Enochian "\xE000\xE001\xE002"
  ]

-- | Input C: an Aramaic-tagged token is four glyphs, not a triliteral
-- root — the Aramaic root-layer pass fails.
aramaicBreakInput :: [Token]
aramaicBreakInput =
  [ Token Latin    "Lux"
  , Token Hebrew   "\x05D0\x05D1\x05D2"
  , Token Arabic   "\x0627\x0644\x0646"
  , Token Aramaic  "\x10840\x10841\x10842\x10843"
  , Token Enochian "\xE000\xE001\xE002"
  ]

-- ---------------------------------------------------------------------------
-- Reporting
-- ---------------------------------------------------------------------------

showToken :: Token -> String
showToken t = "[" ++ show (tokenScript t) ++ "] " ++ tokenText t

passStatus :: Bool -> String
passStatus True  = "PASS"
passStatus False = "FAIL"

verdictLine :: Verdict -> String
verdictLine Certified     = "CERTIFIED — all 5 passes agree"
verdictLine (Rejected fs) = "REJECTED — failed pass(es): " ++ intercalate ", " fs

report :: String -> [Token] -> IO ()
report label toks = do
  putStrLn ("-- " ++ label ++ " (" ++ show (length toks) ++ " tokens) --")
  mapM_ (\t -> putStrLn ("   token " ++ showToken t)) toks
  mapM_ (\p -> putStrLn ("   pass " ++ passName p ++ ": " ++ passStatus (passCheck p toks))) passes
  putStrLn ("   METATRON verdict: " ++ verdictLine (metatron toks))

main :: IO ()
main = do
  -- Force UTF-8 on stdout so glyphs print under any locale.
  hSetEncoding stdout utf8
  putStrLn "ERE v1.0 — Enochian Reconstruction Engine (five-pass core demo)"
  putStrLn "Passes: Enochian, Latin, Hebrew, Arabic, Aramaic"
  putStrLn ""
  report "Input A: valid multilingual stream" certifiedInput
  putStrLn ""
  report "Input B: Latin token carries a digit" latinBreakInput
  putStrLn ""
  report "Input C: Aramaic token is not a triliteral root" aramaicBreakInput
