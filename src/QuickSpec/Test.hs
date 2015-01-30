{-# LANGUAGE CPP, GeneralizedNewtypeDeriving, DeriveDataTypeable #-}
module QuickSpec.Test where

#include "errors.h"
import Data.Constraint
import Data.Maybe
import QuickSpec.Base
import QuickSpec.Signature
import QuickSpec.Term
import QuickSpec.TestSet
import QuickSpec.Type
import System.Random
import Test.QuickCheck
import Test.QuickCheck.Gen
import Test.QuickCheck.Random
import Control.Monad
import Data.Functor.Identity

defaultTypes :: Typed a => Type -> a -> a
defaultTypes ty = typeSubst (const ty)

makeTester :: (a -> Term) -> [Variable -> Value Identity] -> [(QCGen, Int)] -> Signature -> Type -> Maybe (Value (TypedTestSet a))
makeTester toTerm vals tests sig ty = do
  i <- listToMaybe (findInstanceOf sig (defaultTypes (defaultTo_ sig) ty))
  case unwrap (i :: Value Observe1) of
    Observe1 obs `In` w ->
      case unwrap obs of
        Observe Dict eval `In` w' ->
          return . wrap w' $
            emptyTypedTestSet (tester (defaultTypes (defaultTo_ sig) . toTerm) vals tests (eval . runIdentity . reunwrap w))

tester :: Ord b => (a -> Term) -> [Variable -> Value Identity] -> [(QCGen, Int)] -> (Value Identity -> Gen b) -> a -> Maybe [b]
tester toTerm vals tests eval t =
  Just [ unGen (eval (evaluateTm val (toTerm t))) g n | (val, (g, n)) <- zip vals tests ]

env :: Signature -> Type -> Value Gen
env sig ty =
  case findInstanceOf sig ty of
    [] ->
      fromMaybe __ $
      cast ty $
      toValue (ERROR $ "missing arbitrary instance for " ++ prettyShow ty :: Gen A)
    (i:_) -> i

genSeeds :: Int -> IO [(QCGen, Int)]
genSeeds maxSize = do
  rnd <- newQCGen
  let rnds rnd = rnd1 : rnds rnd2 where (rnd1, rnd2) = split rnd
  return (zip (rnds rnd) (concat (repeat [0,2..maxSize])))

