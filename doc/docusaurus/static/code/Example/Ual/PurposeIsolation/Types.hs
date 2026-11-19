{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}

module Example.Ual.PurposeIsolation.Types (WitnessRedeemer (..)) where

import GHC.Generics (Generic)
import PlutusTx.Blueprint
  ( HasBlueprintDefinition
  , HasBlueprintSchema (..)
  , Schema (..)
  , emptyBytesSchema
  , emptySchemaInfo
  )
import PlutusTx.Builtins (BuiltinByteString)
import PlutusTx.IsData.Class (FromData (..), ToData (..))
import Prelude (Show, (<$>))

-- A contract-defined Haskell type whose wire representation is a Data byte
-- string. The CLI uses this very FromData instance on the replayed witness.
newtype WitnessRedeemer = WitnessRedeemer BuiltinByteString
  deriving stock (Generic, Show)
  deriving anyclass (HasBlueprintDefinition)

instance HasBlueprintSchema WitnessRedeemer referencedTypes where
  schema = SchemaBytes emptySchemaInfo emptyBytesSchema

instance ToData WitnessRedeemer where
  toBuiltinData (WitnessRedeemer bytes) = toBuiltinData bytes

instance FromData WitnessRedeemer where
  fromBuiltinData raw = WitnessRedeemer <$> fromBuiltinData raw
