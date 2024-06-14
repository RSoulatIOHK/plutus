-- editorconfig-checker-disable-file

{-# LANGUAGE TypeOperators #-}

module Benchmarks.Bitwise (makeBenchmarks) where

import Common
import Generators

import PlutusCore
import PlutusCore.Evaluation.Machine.ExMemoryUsage

import Criterion.Main
import Data.ByteString qualified as BS
import Hedgehog qualified as H


---------------- ByteString builtins ----------------

-- Smallish bytestring inputs: 150 entries.  Note that the length of a
-- bytestring is eight times the size.
smallerByteStrings150 :: H.Seed -> [BS.ByteString]
smallerByteStrings150 seed = makeSizedByteStrings seed [1..150]

-- Make an integer of size n which encodes to 0xFF...FF
allFF :: Int -> Integer
allFF n = 256^(8*n) - 1

------------------------- ByteStringToInteger -------------------------

{- Experiments show that the times for big-endian and little-endian conversions
   are very similar, with big-endian conversion perhaps taking a fraction
   longer.  We just generate a costing function for big-endian conversion and
   use that for the little-endian conversion as well.  A quadratic function
   fitted to inputs of size up to 150 gives a good fit and extrapolates well to
   larger inputs. -}
benchByteStringToInteger :: Benchmark
benchByteStringToInteger =  createTwoTermBuiltinBenchElementwise ByteStringToInteger []
                            (repeat True) (smallerByteStrings150 seedA)


------------------------- IntegerToByteString -------------------------

{- We have four possibilities for integer to bytestring conversions: they can be
 big- or little-endian, and they can also be of bounded or unbounded width.
 Experiments show that all of these take about the same time, with the bounded
 big-endian conversion taking a few percent longer than the other three
 possiblities.  We just benchmark that and use the model for all of the
 possibilities.  The bounded conversions can require some extra work to pad the
 result to the required width, for example if we ask to convert the integer 2 to
 a bytestring of width 1000.  We use a quadratic costing function which uses
 only the size of the integer, but this is safe because the implementation uses
 a single function call to generate the padding and experiments show that the
 time required for this is negligible in comparison to the conversion time.
 It's important to make sure that the memory cost does take account of the width
 though. -}

-- Make sure that the input integer really does require the full width so that
-- the conversion does the maximum amount of work.
benchIntegerToByteString :: Benchmark
benchIntegerToByteString =
    let b = IntegerToByteString
        widths = [1..150]
        inputs = fmap allFF widths
        -- This is like createThreeTermBuiltinBenchElementwise, but we want to
        -- make sure that the width appears literally in the benchmark name.
        createBench l =
            let mkOneBM (e, width, n) =
                      -- Widths are in words: we need to convert those to widths in bytes for the implementation
                      let width' = 8 * fromIntegral width
                      in bgroup (showMemoryUsage e) [
                              bgroup (showMemoryUsage (LiteralByteSize width')) [mkBM e width' n]
                             ]
                          where mkBM x y z = benchDefault (showMemoryUsage z) $ mkApp3 b [] x y z
            in bgroup (show b) $ fmap mkOneBM l

    in createBench $ zip3 (repeat True) widths inputs

benchAndByteString :: Benchmark
benchAndByteString = undefined
-- Benchmark with equal-sized inputs: it should be linear in the size.
-- Initially check what happens for different-sized inputs with padding and
-- truncation.  Presumably both of these will be bounded by the same-size case.


benchComplementByteString :: Benchmark
benchComplementByteString = undefined
-- This should be a straightforward liear function of the size.

benchReadBit :: Benchmark
benchReadBit = undefined
-- Linear in length and/or position?  Maybe pretty much constant time.

benchWriteBits :: Benchmark
benchWriteBits = undefined
-- The function uses pokeByteOff, which updates a byte in place, presumably in
-- constant time.  If readBit is constant time then this should be linear in the
-- size of the second argument.

benchReplicateByteString :: Benchmark
benchReplicateByteString = undefined
-- This will be linear in the first argument (the number of replications), but
-- may appear constant time.

benchShiftByteString :: Benchmark
benchShiftByteString = undefined
-- Linear in both arguments?

benchRotateByteString :: Benchmark
benchRotateByteString = undefined
-- Linear in both arguments?

benchCountSetBits :: Benchmark
benchCountSetBits = undefined
-- This will presumably be linear in the size of the argument.

benchFindFirstSetBit :: Benchmark
benchFindFirstSetBit = undefined
-- This will presumably be linear in the size of the argument.

makeBenchmarks :: [Benchmark]
makeBenchmarks =
    [ benchByteStringToInteger
    , benchIntegerToByteString
    , benchAndByteString
    , benchComplementByteString
    , benchReadBit
    , benchWriteBits
    , benchReplicateByteString
    , benchShiftByteString
    , benchRotateByteString
    , benchCountSetBits
    , benchFindFirstSetBit
    ]
