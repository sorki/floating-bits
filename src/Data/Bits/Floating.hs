{-# LANGUAGE MultiParamTypeClasses  #-}
{-# LANGUAGE FunctionalDependencies #-}
-----------------------------------------------------------------------------
-- |
-- Copyright   :  (C) 2015 Anselm Jonas Scholl
-- License     :  BSD3
-- Maintainer  :  Anselm Jonas Scholl <anselm.scholl@tu-harburg.de>
-- Stability   :  experimental
-- Portability :  GHC-specific
--
-- Conversions between floating point values and integral values preserving
-- the bit-patterns.
----------------------------------------------------------------------------
module Data.Bits.Floating (

    -- * Bitwise operations
     FloatingBits(..)

    -- * Printing
    ,ShowFloat(..)

    -- * Utility functions
    ,fromCFloat
    ,fromCDouble
    ) where

import Data.Bits
import Data.Bits.Floating.Prim
import Data.Bits.Floating.Ulp
import Data.Word
import Numeric (showHex)

import Foreign.C.Types

class (Floating f, Integral w) => FloatingBits f w | f -> w where
    -- | Coerce a floating point number to an integral number preserving the
    --   bitwise representation.
    coerceToWord :: f -> w
    -- | Coerce a integral number to an floating point number preserving the
    --   bitwise representation.
    --
    --   Note: It is not always possible to do this. In particular, if we coerce
    --   the bit pattern of a NaN value, we might get a NaN value with a different
    --   bit pattern than we wanted, so it is possible that
    --   @'coerceToWord' ('coerceToFloat' w) /= w@.
    coerceToFloat :: w -> f
    -- | Return the next floating point value in the direction of +INF.
    --   If the argument is NaN, NaN is returned. If the argument is +INF,
    --   +INF is returned. If the argument is 0.0, the minimum value greater than
    --   0.0 is returned.
    nextUp :: f -> f
    -- | Return the next floating point value in the direction of -INF.
    --   If the argument is NaN, NaN is returned. If the argument is -INF,
    --   +INF is returned. If the argument is 0.0, the minimum value smaller than
    --   0.0 is returned.
    nextDown :: f -> f
    -- | Return the size of an ulp of the argument. If the argument is NaN, NaN
    --   is returned. If the argument is +INF or -INF, +INF is returned. If
    --   the argument is 0.0, the minimum value greater than 0.0 is returned.
    --
    --   If @x@ is not NaN, @'ulp' x == 'ulp' (-x)@ holds.
    ulp :: f -> f


class ShowFloat f where
    {-# MINIMAL showsFloat | showFloat #-}
    -- | Like 'showFloat', but prepends the value to another string.
    showsFloat :: f -> ShowS
    showsFloat f s = showFloat f ++ s
    -- | Convert a float to a string, but show additional information if it is
    --   a NaN value.
    showFloat :: f -> String
    showFloat f = showsFloat f ""

{-# RULES "showFloat/++" forall f s . showFloat f ++ s = showsFloat f s #-}

instance FloatingBits Float Word32 where
    {-# INLINE coerceToWord #-}
    coerceToWord  = float2WordBitwise
    {-# INLINE coerceToFloat #-}
    coerceToFloat = word2FloatBitwise
    {-# INLINE nextUp #-}
    nextUp        = floatNextUlp
    {-# INLINE nextDown #-}
    nextDown      = floatPrevUlp
    {-# INLINE ulp #-}
    ulp           = floatUlp

instance FloatingBits Double Word64 where
    {-# INLINE coerceToWord #-}
    coerceToWord  = double2WordBitwise
    {-# INLINE coerceToFloat #-}
    coerceToFloat = word2DoubleBitwise
    {-# INLINE nextUp #-}
    nextUp        = doubleNextUlp
    {-# INLINE nextDown #-}
    nextDown      = doublePrevUlp
    {-# INLINE ulp #-}
    ulp           = doubleUlp

instance FloatingBits CFloat Word32 where
    {-# INLINE coerceToWord #-}
    coerceToWord  = coerceToWord . fromCFloat
    {-# INLINE coerceToFloat #-}
    coerceToFloat = CFloat . coerceToFloat
    {-# INLINE nextUp #-}
    nextUp        = CFloat . nextUp . fromCFloat
    {-# INLINE nextDown #-}
    nextDown      = CFloat . nextDown . fromCFloat
    {-# INLINE ulp #-}
    ulp           = CFloat . ulp . fromCFloat

instance FloatingBits CDouble Word64 where
    {-# INLINE coerceToWord #-}
    coerceToWord  = coerceToWord . fromCDouble
    {-# INLINE coerceToFloat #-}
    coerceToFloat = CDouble . coerceToFloat
    {-# INLINE nextUp #-}
    nextUp        = CDouble . nextUp . fromCDouble
    {-# INLINE nextDown #-}
    nextDown      = CDouble . nextDown . fromCDouble
    {-# INLINE ulp #-}
    ulp           = CDouble . ulp . fromCDouble

-- | Cast a 'CFloat' to a 'Float'.
{-# INLINE fromCFloat #-}
fromCFloat :: CFloat -> Float
fromCFloat (CFloat f) = f

-- | Cast a 'CDouble' to a 'Double'.
{-# INLINE fromCDouble #-}
fromCDouble :: CDouble -> Double
fromCDouble (CDouble d) = d

instance ShowFloat Float where
    showsFloat f | isNaN f   = showsFloatNaN f
                 | otherwise = shows f

instance ShowFloat Double where
    showsFloat f | isNaN f   = showsDoubleNaN f
                 | otherwise = shows f

instance ShowFloat CFloat where
    showsFloat = showsFloat . fromCFloat

instance ShowFloat CDouble where
    showsFloat = showsFloat . fromCDouble

-- | Show a 'Float' NaN value.
showsFloatNaN :: Float -> ShowS
showsFloatNaN f = sign . nan . (\ s -> '(':'0':'x':s) . showHex (w .&. 0x3FFFFF) . (')':)
    where
        w = coerceToWord f
        sign | w .&. 0x80000000 /= 0 = ('-':)
             | otherwise             = id
        nan s | w .&. 0x00400000 /= 0 = "qNaN" ++ s
              | otherwise             = "sNaN" ++ s

-- | Show a 'Double' NaN value.
showsDoubleNaN :: Double -> ShowS
showsDoubleNaN f = sign . nan . (\ s -> '(':'0':'x':s) . showHex (w .&. 0x0007FFFFFFFFFFFF) . (')':)
    where
        w = coerceToWord f
        sign | w .&. 0x8000000000000000 /= 0 = ('-':)
             | otherwise                     = id
        nan s | w .&. 0x0008000000000000 /= 0 = "qNaN" ++ s
              | otherwise                     = "sNaN" ++ s
