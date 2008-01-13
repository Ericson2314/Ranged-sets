-----------------------------------------------------------------------------
-- |
-- Module      :  Data.Ranged.Boundaries
-- Copyright   :  (c) Paul Johnson 2006
-- License     :  BSD-style
-- Maintainer  :  paul@cogito.org.uk
-- Stability   :  experimental
-- Portability :  portable
--
-----------------------------------------------------------------------------

module Data.Ranged.Boundaries (
   DiscreteOrdered,
   adjacent,
   enumAdjacent,
   boundedAdjacent,
   Boundary (..),
   above,
   (/>/)
) where

import Data.Ratio
import Test.QuickCheck

infix 4 />/

{- |
Distinguish between dense and sparse ordered types.  A dense type is
one in which any two values @v1 < v2@ have a third value @v3@ such that
@v1 < v3 < v2@.

In theory the floating types are dense, although in practice they can only have
finitely many values.  This class treats them as dense.

Tuples up to 4 members are declared as instances.  Larger tuples may be added
if necessary.

This approach was suggested by Ben Rudiak-Gould on comp.lang.functional.
-}
class Ord a => DiscreteOrdered a where
   -- | Two values @x@ and @y@ are adjacent if @x < y@ and there does not
   -- exist a third value between them.  Always @False@ for dense types.
   adjacent :: a -> a -> Bool

instance DiscreteOrdered Bool         where adjacent = boundedAdjacent
instance DiscreteOrdered Ordering     where adjacent = boundedAdjacent
instance DiscreteOrdered Char         where adjacent = boundedAdjacent
instance DiscreteOrdered Int          where adjacent = boundedAdjacent
instance DiscreteOrdered Integer      where adjacent = enumAdjacent
instance Integral a => DiscreteOrdered (Ratio a)
                                      where adjacent _ _ = False
instance DiscreteOrdered Float        where adjacent _ _ = False
instance DiscreteOrdered Double       where adjacent _ _ = False
instance Ord a => DiscreteOrdered [a] where adjacent _ _ = False
instance (Ord a, DiscreteOrdered b) => DiscreteOrdered (a, b)
   where adjacent (x1, x2) (y1, y2) = (x1 == y1) && adjacent x2 y2
instance (Ord a, Ord b, DiscreteOrdered c) => DiscreteOrdered (a, b, c)
   where
      adjacent (x1, x2, x3) (y1, y2, y3) =
         (x1 == y1) && (x2 == y2) && adjacent x3 y3
instance (Ord a, Ord b, Ord c, DiscreteOrdered d) =>
         DiscreteOrdered (a, b, c, d)
   where
      adjacent (x1, x2, x3, x4) (y1, y2, y3, y4) =
         (x1 == y1) && (x2 == y2) && (x3 == y3) && adjacent x4 y4

-- | Check adjacency for sparse enumerated types (i.e. where there
-- is no value between @x@ and @succ x@).  Use as the definition of
-- "adjacent" for most enumerated types.
enumAdjacent :: (Ord a, Enum a) => a -> a -> Bool
enumAdjacent x y = (succ x == y)

-- | Check adjacency, allowing for case where x = maxBound.  Use as the
-- definition of "adjacent" for bounded enumerated types such as Int and Char.
boundedAdjacent :: (Ord a, Enum a) => a -> a -> Bool
boundedAdjacent x y = if x < y then succ x == y else False


{- |
A Boundary is a division of an ordered type into values above
and below the boundary.  No value can sit on a boundary.

Known bug: for Bounded types

* @BoundaryAbove maxBound < BoundaryAboveAll@

* @BoundaryBelow minBound > BoundaryBelowAll@

This is incorrect because there are no possible values in
between the left and right sides of these inequalities.
-}

data Boundary a =
      -- | The argument is the highest value below the boundary.
      BoundaryAbove a |
      -- | The argument is the lowest value above the boundary.
      BoundaryBelow a |
      -- | The boundary above all values.
      BoundaryAboveAll |
      -- | The boundary below all values.
      BoundaryBelowAll
   deriving (Show)

-- | True if the value is above the boundary, false otherwise.
above :: Ord v => Boundary v -> v -> Bool
above (BoundaryAbove b) v    = v > b
above (BoundaryBelow b) v    = v >= b
above BoundaryAboveAll _     = False
above BoundaryBelowAll _     = True

-- | Same as 'above', but with the arguments reversed for more intuitive infix
-- usage.
(/>/) :: Ord v => v -> Boundary v -> Bool
(/>/) = flip above

instance (DiscreteOrdered a) => Eq (Boundary a) where
   b1 == b2  = compare b1 b2 == EQ

instance (DiscreteOrdered a) => Ord (Boundary a) where
   -- Comparison alogrithm based on brute force and ignorance:
   -- enumerate all combinations.

   compare boundary1 boundary2 =
      case boundary1 of
         BoundaryAbove b1 ->
            case boundary2 of
               BoundaryAbove b2 -> compare b1 b2
               BoundaryBelow b2 ->
                  if b1 < b2
                     then
                        if adjacent b1 b2 then EQ else LT
                     else GT
               BoundaryAboveAll -> LT
               BoundaryBelowAll -> GT
         BoundaryBelow b1 ->
            case boundary2 of
               BoundaryAbove b2 ->
                  if b1 > b2
                     then
                        if adjacent b2 b1 then EQ else GT
                     else LT
               BoundaryBelow b2 -> compare b1 b2
               BoundaryAboveAll -> LT
               BoundaryBelowAll -> GT
         BoundaryAboveAll ->
            case boundary2 of
               BoundaryAboveAll -> EQ
               _        -> GT
         BoundaryBelowAll ->
            case boundary2 of
               BoundaryBelowAll -> EQ
               _        -> LT

-- QuickCheck Generator

instance Arbitrary a => Arbitrary (Boundary a) where
   arbitrary = frequency [
      (1, return BoundaryAboveAll),
      (1, return BoundaryBelowAll),
      (18, do
         v <- arbitrary
         oneof [return $ BoundaryAbove v, return $ BoundaryBelow v]
      )]
   coarbitrary BoundaryBelowAll   = variant 0
   coarbitrary BoundaryAboveAll   = variant 1
   coarbitrary (BoundaryBelow v)  = variant 2 . coarbitrary v
   coarbitrary (BoundaryAbove v)  = variant 3 . coarbitrary v

