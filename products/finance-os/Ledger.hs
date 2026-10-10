{-
  Ledger.hs — Finance OS (SEIT product recreation)
  Copyright (C) 2026 Ahmad Ali Parr / SnapKitty Research Lab
  SPDX-License-Identifier: LicenseRef-SEIT-FSL-Donation-1.0

  Functional source, donation-gated runtime: you may read, share, and
  modify this source freely; running it requires a qualifying donation
  to the licensor. See LICENSE.txt for the full terms. No warranty.
-}
-- | Pure-functional double-entry ledger core.
--
-- This module is 100% pure: no IO anywhere. A 'Ledger' is a map from
-- account to a signed balance in integer cents (debits add, credits
-- subtract). 'post' validates a 'Posting' and either rejects it with a
-- 'PostError' or returns the updated ledger.
module Ledger
  ( Account (..)
  , AccountType (..)
  , Side (..)
  , Leg (..)
  , Posting (..)
  , PostError (..)
  , Ledger
  , emptyLedger
  , post
  , trialBalance
  , accountType
  , accountName
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map

-- | The five standard account classes.
data AccountType = Assets | Liabilities | Equity | Income | Expenses
  deriving (Eq, Show)

-- | Chart of accounts: a small community-finance chart covering all five
-- classes. Cash (Assets), MemberDeposits (Liabilities), Capital (Equity),
-- FeeIncome (Income), OpExpenses (Expenses).
data Account
  = Cash
  | MemberDeposits
  | Capital
  | FeeIncome
  | OpExpenses
  deriving (Eq, Ord, Show, Enum, Bounded)

accountType :: Account -> AccountType
accountType Cash           = Assets
accountType MemberDeposits = Liabilities
accountType Capital        = Equity
accountType FeeIncome      = Income
accountType OpExpenses     = Expenses

accountName :: Account -> String
accountName Cash           = "Cash"
accountName MemberDeposits = "Member Deposits"
accountName Capital        = "Capital"
accountName FeeIncome      = "Fee Income"
accountName OpExpenses     = "Operating Expenses"

-- | A leg of a double-entry posting.
data Side = Debit | Credit
  deriving (Eq, Show)

data Leg = Leg
  { legAccount :: Account
  , legSide    :: Side
  , legAmount  :: Integer -- ^ strictly positive, integer cents
  } deriving (Eq, Show)

-- | A balanced set of legs plus a human-readable memo.
data Posting = Posting
  { postingMemo :: String
  , postingLegs :: [Leg]
  } deriving (Eq, Show)

-- | Why a posting was rejected.
data PostError
  = EmptyLegs
  | NonPositiveAmount Account Integer
  | Unbalanced Integer Integer -- ^ (total debits, total credits)
  deriving (Eq, Show)

-- | Signed cents per account: debit legs add, credit legs subtract.
newtype Ledger = Ledger (Map Account Integer)
  deriving (Eq, Show)

emptyLedger :: Ledger
emptyLedger = Ledger Map.empty

-- | Validate and apply a posting. The posting is accepted only if it has
-- at least one leg, every leg amount is positive, and total debits equal
-- total credits. The ledger itself is untouched on rejection.
post :: Posting -> Ledger -> Either PostError Ledger
post p (Ledger m)
  | null (postingLegs p) = Left EmptyLegs
  | otherwise =
      case firstBadAmount (postingLegs p) of
        Just (a, n) -> Left (NonPositiveAmount a n)
        Nothing ->
          if totalDebits == totalCredits
            then Right (Ledger (foldl' apply m (postingLegs p)))
            else Left (Unbalanced totalDebits totalCredits)
  where
    firstBadAmount :: [Leg] -> Maybe (Account, Integer)
    firstBadAmount ls =
      case [(legAccount l, legAmount l) | l <- ls, legAmount l <= 0] of
        []    -> Nothing
        (x:_) -> Just x
    totalDebits  = sum [legAmount l | l <- postingLegs p, legSide l == Debit]
    totalCredits = sum [legAmount l | l <- postingLegs p, legSide l == Credit]
    apply :: Map Account Integer -> Leg -> Map Account Integer
    apply acc l =
      Map.insertWith (+) (legAccount l) (signed (legSide l) (legAmount l)) acc
    signed :: Side -> Integer -> Integer
    signed Debit  n = n
    signed Credit n = negate n

-- | Every account with a non-zero balance, in chart order. Each entry is
-- @(account, signed cents)@: positive means a debit balance, negative a
-- credit balance.
trialBalance :: Ledger -> [(Account, Integer)]
trialBalance (Ledger m) =
  [ (a, b)
  | a <- [minBound .. maxBound]
  , let b = Map.findWithDefault 0 a m
  , b /= 0
  ]
