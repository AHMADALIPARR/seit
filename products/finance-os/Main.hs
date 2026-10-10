{-
  Main.hs — Finance OS (SEIT product recreation)
  Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
  SPDX-License-Identifier: LicenseRef-SEIT-FSL-Donation-1.0

  Functional source, donation-gated runtime: you may read, share, and
  modify this source freely; running it requires a qualifying donation
  to the licensor. See LICENSE.txt for the full terms. No warranty.
-}
-- | Finance OS demo: posts a few community-finance transactions, rejects
-- one bad one, then prints the trial balance and the hash-chained
-- receipt trail.
module Main (main) where

import Ledger
  ( Account (..)
  , Leg (..)
  , Ledger
  , PostError (..)
  , Posting (..)
  , Side (..)
  , accountName
  , accountType
  , emptyLedger
  , post
  , trialBalance
  )
import Receipt (Receipt (..), digestHex, issueReceipts)

-- | Amounts are integer cents.
cents :: Int -> Integer
cents = fromIntegral

demoPostings :: [Posting]
demoPostings =
  [ Posting
      { postingMemo = "Member #7 capital contribution"
      , postingLegs =
          [ Leg Cash Debit (cents 100000)
          , Leg Capital Credit (cents 100000)
          ]
      }
  , Posting
      { postingMemo = "Member savings deposits received"
      , postingLegs =
          [ Leg Cash Debit (cents 50000)
          , Leg MemberDeposits Credit (cents 50000)
          ]
      }
  , Posting
      { postingMemo = "Office rent and supplies"
      , postingLegs =
          [ Leg OpExpenses Debit (cents 12000)
          , Leg Cash Credit (cents 12000)
          ]
      }
  , Posting
      { postingMemo = "Origination fee income"
      , postingLegs =
          [ Leg Cash Debit (cents 8000)
          , Leg FeeIncome Credit (cents 8000)
          ]
      }
  ]

-- | Unbalanced posting used to prove the ledger rejects bad input.
badPosting :: Posting
badPosting =
  Posting
    { postingMemo = "Cooked books (should be rejected)"
    , postingLegs =
        [ Leg Cash Debit (cents 10000)
        , Leg FeeIncome Credit (cents 9000)
        ]
    }

applyAll :: [Posting] -> Either PostError (Ledger, [Posting])
applyAll = foldl' step (Right (emptyLedger, []))
  where
    step :: Either PostError (Ledger, [Posting]) -> Posting -> Either PostError (Ledger, [Posting])
    step (Left e) _ = Left e
    step (Right (l, acc)) p =
      case post p l of
        Left e   -> Left e
        Right l' -> Right (l', acc ++ [p])

formatCents :: Integer -> String
formatCents n =
  sign ++ dollars ++ "." ++ cents2
  where
    sign   = if n < 0 then "-" else ""
    a      = abs n
    dollars = show (a `div` 100)
    c      = show (a `mod` 100)
    cents2 = if length c == 1 then '0' : c else c

printTrialBalance :: Ledger -> IO ()
printTrialBalance l = do
  putStrLn "Trial balance"
  putStrLn "---------------------------------------------"
  mapM_ printLine (trialBalance l)
  putStrLn "---------------------------------------------"
  putStrLn ("Total debits :  " ++ formatCents totalDebits)
  putStrLn ("Total credits:  " ++ formatCents totalCredits)
  putStrLn ("Balanced     :  " ++ show (totalDebits == totalCredits))
  where
    printLine :: (Account, Integer) -> IO ()
    printLine (a, bal) = do
      let (side, amt) =
            if bal >= 0 then ("DR", bal) else ("CR", negate bal)
      putStrLn
        ( padRight 20 (accountName a)
            ++ "  " ++ padRight 11 (show (accountType a))
            ++ "  " ++ side
            ++ "  " ++ formatCents amt
        )
    (totalDebits, totalCredits) =
      foldl'
        ( \(d, c) (_, bal) ->
            if bal >= 0 then (d + bal, c) else (d, c + negate bal)
        )
        (0, 0)
        (trialBalance l)
    padRight :: Int -> String -> String
    padRight w s = s ++ replicate (max 0 (w - length s)) ' '

printReceipts :: [Receipt] -> IO ()
printReceipts rs = do
  putStrLn ""
  putStrLn "Receipt chain (hash of previous receipt + posting)"
  putStrLn "---------------------------------------------"
  mapM_ printOne rs
  where
    printOne :: Receipt -> IO ()
    printOne r = do
      putStrLn ("#" ++ show (receiptIndex r) ++ "  " ++ digestHex (receiptDigest r))
      putStrLn ("     " ++ postingMemo (receiptPosting r))

describeError :: PostError -> String
describeError EmptyLegs = "rejected: posting has no legs"
describeError (NonPositiveAmount a n) =
  "rejected: non-positive amount on " ++ accountName a ++ ": " ++ show n
describeError (Unbalanced d c) =
  "rejected: debits (" ++ formatCents d ++ ") /= credits (" ++ formatCents c ++ ")"

main :: IO ()
main = do
  putStrLn "=== Finance OS demo ==="
  putStrLn ""
  case post badPosting emptyLedger of
    Left e -> putStrLn ("Unbalanced demo posting " ++ describeError e ++ ".")
    Right _ -> putStrLn "BUG: unbalanced posting was accepted!"
  putStrLn ""
  case applyAll demoPostings of
    Left e -> putStrLn ("Unexpected posting failure: " ++ describeError e)
    Right (ledger, accepted) -> do
      putStrLn ("Accepted " ++ show (length accepted) ++ " postings.")
      putStrLn ""
      printTrialBalance ledger
      printReceipts (issueReceipts accepted)
