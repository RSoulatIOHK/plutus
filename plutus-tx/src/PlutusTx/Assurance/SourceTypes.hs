{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

{-| Local Haskell provenance for CEX decoding. This is deliberately separate
from the portable CIP-57 blueprint and assurance documents: their Data
schemas describe the wire format, while a source project chooses the
Haskell FromData instance used to display a replayed witness. -}
module PlutusTx.Assurance.SourceTypes (sourceTypesManifest) where

import Data.Aeson (Value (..), object, (.=))
import Data.Map qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Typeable (TypeRep, splitTyConApp, tyConModule, tyConName, tyConPackage)
import PlutusTx.Blueprint.Argument (ArgumentBlueprint (..))
import PlutusTx.Blueprint.Contract (ContractBlueprint (..))
import PlutusTx.Blueprint.Definition.Id (definitionIdToText)
import PlutusTx.Blueprint.Definition.Internal (definitionsToTypeReps)
import PlutusTx.Blueprint.Schema (Schema (..))
import PlutusTx.Blueprint.Validator (ValidatorBlueprint (..))
import Prelude

typeDescriptor :: TypeRep -> Value
typeDescriptor rep =
  let (constructor, arguments) = splitTyConApp rep
   in object
        [ "package" .= tyConPackage constructor
        , "module" .= tyConModule constructor
        , "name" .= tyConName constructor
        , "arguments" .= map typeDescriptor arguments
        ]

{-| The hash binds source type names to one exact generated blueprint. A
consumer must reject a stale manifest, and must check that Haskell ToData
reproduces the exact Data argument confirmed by compiled UPLC replay. -}
sourceTypesManifest :: Text -> ContractBlueprint -> Value
sourceTypesManifest blueprintSha256 MkContractBlueprint {..} =
  object
    [ "format" .= ("plinth-source-types-v1" :: Text)
    , "blueprintSha256" .= blueprintSha256
    , "validators" .= map validator (Set.toList contractValidators)
    ]
  where
    definitions = definitionsToTypeReps contractDefinitions
    argument MkArgumentBlueprint {argumentSchema = SchemaDefinitionRef definitionId} =
      maybe
        Null
        (\rep -> object ["definition" .= definitionIdToText definitionId, "type" .= typeDescriptor rep])
        (Map.lookup definitionId definitions)
    argument _ = Null
    validator MkValidatorBlueprint {..} =
      object
        [ "id" .= validatorId
        , "datum" .= maybe Null argument validatorDatum
        , "redeemer" .= argument validatorRedeemer
        ]
