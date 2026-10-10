{-
  Main.hs — Sovereign Mesh (SEIT product recreation)
  Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
  SPDX-License-Identifier: LicenseRef-SEIT-FSL-Donation-1.0

  Functional source, donation-gated runtime: you may read, share, and
  modify this source freely; running it requires a qualifying donation
  to the licensor. See LICENSE.txt for the full terms. No warranty.
-}
-- | Sovereign Mesh (SACM): a 24-agent stochastic autonomous compute mesh
-- recreated at small scale. Every decision is checked against all 10
-- constitutional axioms before acceptance; any violation rejects the
-- decision and names the violated axiom. Accepted decisions are appended
-- to a hash-chained WORM log.
--
-- HONEST MODELING NOTE: the "signature" on a decision is a keyed
-- SHA-256 (secret || canonical decision bytes), NOT Ed25519. There is no
-- asymmetric cryptography anywhere in this recreation. See README.
module Main (main) where

import Control.Monad (foldM)
import Data.List (find, intercalate)
import Data.Maybe (fromMaybe)
import Sha256 (sha256Hex)

-- ---------------------------------------------------------------------------
-- The 10 constitutional axioms (exact names from the SEIT description).
-- ---------------------------------------------------------------------------

data Axiom
  = NO_MAGMA_EXPOSURE
  | NO_EXTERNAL_AI_DEP
  | WORM_IMMUTABILITY
  | NO_CLEARANCE_ESCALATION
  | SOVEREIGN_INFRASTRUCTURE
  | ACCOUNTABLE_AUTHORITY
  | ENTROPY_IS_CATALYST
  | SIGN_BEFORE_STORE
  | MARINATE_BEFORE_EXECUTE
  | ISOLATION_BY_DEFAULT
  deriving (Eq, Show)

-- ---------------------------------------------------------------------------
-- Agents
-- ---------------------------------------------------------------------------

data Agent = Agent
  { agentId :: Int
  , agentName :: String
  , trustLevel :: Int -- doubles as the agent's clearance level (1..4)
  }
  deriving (Eq, Show)

agentNames :: [String]
agentNames =
  [ "wren", "kestrel", "merlin", "osprey", "harrier", "falcon"
  , "eagle", "hawk", "raven", "crow", "dove", "swan"
  , "heron", "ibis", "crane", "stork", "gull", "tern"
  , "auk", "petrel", "albatross", "condor", "vulture", "kite"
  ]

buildAgents :: [Agent]
buildAgents =
  [ Agent i n (1 + (i - 1) `mod` 4)
  | (i, n) <- zip [1 ..] agentNames
  ]

findAgent :: Int -> [Agent] -> Maybe Agent
findAgent aid = find (\a -> agentId a == aid)

-- Each agent holds a secret used only for the keyed-hash signature model.
agentSecret :: Agent -> String
agentSecret a = "sacm-secret-" ++ show (agentId a)

-- ---------------------------------------------------------------------------
-- Decisions
-- ---------------------------------------------------------------------------

data Target = Sovereign | External deriving (Eq, Show)

data Decision = Decision
  { decId :: Int
  , decAgentId :: Int
  , decAction :: String
  , decClearance :: Int
  , decTarget :: Target
  , decPayloadHash :: String
  , decAuthority :: Maybe String -- accountable authority; required
  , decEntropy :: Maybe Integer -- entropy catalyst; required, > 0
  , decGrant :: Maybe String -- explicit isolation grant; required
  , decMarinationRounds :: Int -- must be >= 1 before execution
  , decExposesInternal :: Bool -- must be False (no magma exposure)
  , decUsesExternalAI :: Bool -- must be False (no external AI dependency)
  , decSignature :: Maybe String -- keyed-hash signature; required
  }
  deriving (Show)

-- Canonical bytes covered by the signature. The signature field itself is
-- excluded (it cannot sign itself).
canonicalDecision :: Decision -> String
canonicalDecision d =
  intercalate
    "|"
    [ show (decId d)
    , show (decAgentId d)
    , decAction d
    , show (decClearance d)
    , show (decTarget d)
    , decPayloadHash d
    , fromMaybe "" (decAuthority d)
    , maybe "" show (decEntropy d)
    , fromMaybe "" (decGrant d)
    , show (decMarinationRounds d)
    , show (decExposesInternal d)
    , show (decUsesExternalAI d)
    ]

-- | Model of a signature: keyed hash of the canonical decision bytes.
-- This is symmetric (HMAC-style), NOT Ed25519.
sign :: Agent -> Decision -> String
sign a d = sha256Hex (agentSecret a ++ "\0" ++ canonicalDecision d)

-- ---------------------------------------------------------------------------
-- Axiom checking: every axiom is a pure predicate over (agent, decision).
-- ---------------------------------------------------------------------------

axioms :: [(Axiom, Agent -> Decision -> Bool)]
axioms =
  [ (NO_MAGMA_EXPOSURE, \_ d -> not (decExposesInternal d))
  , (NO_EXTERNAL_AI_DEP, \_ d -> not (decUsesExternalAI d))
  , (WORM_IMMUTABILITY, \_ d -> not (null (decPayloadHash d)))
  , (NO_CLEARANCE_ESCALATION, \a d -> decClearance d <= trustLevel a)
  , (SOVEREIGN_INFRASTRUCTURE, \_ d -> decTarget d == Sovereign)
  , (ACCOUNTABLE_AUTHORITY, \_ d -> maybe False (not . null) (decAuthority d))
  , (ENTROPY_IS_CATALYST, \_ d -> maybe False (> 0) (decEntropy d))
  , (SIGN_BEFORE_STORE, \a d -> maybe False (== sign a d) (decSignature d))
  , (MARINATE_BEFORE_EXECUTE, \_ d -> decMarinationRounds d >= 1)
  , (ISOLATION_BY_DEFAULT, \_ d -> maybe False (not . null) (decGrant d))
  ]

-- | All axioms violated by this decision (empty = accepted).
violations :: Agent -> Decision -> [Axiom]
violations a d = [ax | (ax, p) <- axioms, not (p a d)]

-- ---------------------------------------------------------------------------
-- WORM log: append-only, hash-chained. No entry is ever mutated.
-- ---------------------------------------------------------------------------

data LogEntry = LogEntry
  { leSeq :: Int
  , leDecision :: Decision
  , lePrevHash :: String
  , leHash :: String
  }
  deriving (Show)

genesisHash :: String
genesisHash = replicate 64 '0'

entryHash :: String -> Decision -> String
entryHash prev d =
  sha256Hex (prev ++ "|" ++ canonicalDecision d ++ "|" ++ fromMaybe "" (decSignature d))

appendEntry :: [LogEntry] -> Decision -> LogEntry
appendEntry entries d =
  let prev = case entries of
        [] -> genesisHash
        _ -> leHash (last entries)
   in LogEntry (length entries) d prev (entryHash prev d)

-- | Recompute every link of the chain; True only if intact.
verifyChain :: [LogEntry] -> Bool
verifyChain [] = True
verifyChain entries =
  all linkOk (zip (genesisHash : map leHash entries) entries)
  where
    linkOk (prev, e) =
      lePrevHash e == prev && leHash e == entryHash prev (leDecision e)

-- ---------------------------------------------------------------------------
-- Demo
-- ---------------------------------------------------------------------------

-- A well-formed decision; the caller signs it (or not) afterwards.
mkDecision :: Int -> Int -> String -> Int -> Decision
mkDecision did aid action clr =
  Decision
    { decId = did
    , decAgentId = aid
    , decAction = action
    , decClearance = clr
    , decTarget = Sovereign
    , decPayloadHash = sha256Hex ("payload-" ++ show did)
    , decAuthority = Just "mesh-council"
    , decEntropy = Just (fromIntegral did * 1000 + 7)
    , decGrant = Just "grant-net-internal"
    , decMarinationRounds = 3
    , decExposesInternal = False
    , decUsesExternalAI = False
    , decSignature = Nothing
    }

demoDecisions :: [Agent] -> [Decision]
demoDecisions agents =
  let signed aid d = case findAgent aid agents of
        Just a -> d {decSignature = Just (sign a d)}
        Nothing -> d
   in [ signed 3 (mkDecision 1 3 "rotate-worm-logs" 2) -- valid
      , mkDecision 2 7 "snapshot-state" 3 -- UNSIGNED -> SIGN_BEFORE_STORE
      , signed 2 (mkDecision 3 2 "rekey-mesh" 4) -- escalation: agent 2 is clearance 2
      , signed 10 ((mkDecision 4 10 "peer-sync" 2) {decGrant = Nothing}) -- no grant
      , signed 1 ((mkDecision 5 1 "update-routes" 1) {decAuthority = Nothing}) -- no authority
      , signed 5 (mkDecision 6 5 "garbage-collect" 1) -- valid
      , (signed 7 (mkDecision 7 7 "snapshot-state" 3)) {decSignature = Just "tampered"} -- bad sig
      ]

submit :: [Agent] -> [LogEntry] -> Decision -> IO [LogEntry]
submit agents entries d = case findAgent (decAgentId d) agents of
  Nothing -> do
    putStrLn
      ( "[SUBMIT] decision #"
          ++ show (decId d)
          ++ ": unknown agent "
          ++ show (decAgentId d)
          ++ " -> REJECTED: UNKNOWN_AGENT"
      )
    return entries
  Just a -> do
    putStrLn
      ( "[SUBMIT] decision #"
          ++ show (decId d)
          ++ " from "
          ++ agentName a
          ++ " (clearance "
          ++ show (trustLevel a)
          ++ "): "
          ++ decAction d
      )
    case violations a d of
      [] -> do
        let e = appendEntry entries d
        putStrLn
          ( "  ACCEPTED -> worm seq "
              ++ show (leSeq e)
              ++ " entry "
              ++ take 12 (leHash e)
              ++ "..."
          )
        return (entries ++ [e])
      vs -> do
        putStrLn ("  REJECTED: " ++ intercalate ", " (map show vs))
        return entries

printEntry :: LogEntry -> IO ()
printEntry e =
  putStrLn
    ( "  seq "
        ++ show (leSeq e)
        ++ " dec#"
        ++ show (decId (leDecision e))
        ++ " prev "
        ++ take 10 (lePrevHash e)
        ++ ".. hash "
        ++ take 10 (leHash e)
        ++ ".."
    )

main :: IO ()
main = do
  let agents = buildAgents
  putStrLn "Sovereign Mesh (SACM) -- 24 agents, 10 constitutional axioms"
  putStrLn
    ( "agents: "
        ++ show (length agents)
        ++ ", axioms: "
        ++ show (length axioms)
        ++ ". No unsigned output is authoritative."
    )
  putStrLn ""
  entries <- foldM (submit agents) [] (demoDecisions agents)
  putStrLn ""
  putStrLn ("WORM log (" ++ show (length entries) ++ " accepted entries):")
  mapM_ printEntry entries
  putStrLn ("chain verified: " ++ show (verifyChain entries))
