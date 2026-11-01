{-# LANGUAGE OverloadedStrings #-}

-- | Expand source templates before building an ordinary assurance document.
module PlutusTx.Ual.Templates (expandPropertyTemplates) where

import Data.List (nub, sort)
import Data.Text qualified as T
import PlutusTx.Blueprint.PlutusVersion (PlutusVersion (PlutusV3))
import PlutusTx.Blueprint.Purpose (Purpose (..), purposeToText)
import PlutusTx.Ual.Error (UalError (..))
import PlutusTx.Ual.Syntax
import Prelude

expandPropertyTemplates :: [ModuleUal] -> Either [UalError] [ModuleUal]
expandPropertyTemplates modules = case concatMap errors expanded of
  [] -> Right [m {ualProperties = [p | Right p <- ps]} | (m, ps) <- expanded]
  es -> Left es
  where
    decls = [d | m <- modules, d <- ualOnchain m]
    expanded = [(m, map expand (ualProperties m)) | m <- modules]
    errors (_, ps) = [e | Left e <- ps]
    expand p = case propertyTemplate p of
      Nothing -> Right p
      Just (PurposeIsolation allowed) -> do
        let invalid = Left . MalformedBlock (propertyLine p)
        target <- case propertyScope p of
          [t] -> Right t
          _ -> invalid "a property template requires exactly one explicit scope"
        d <- case [d | d <- decls, onchainName d == target] of
          [d] -> Right d
          _ -> invalid ("template target is missing or ambiguous: " <> target)
        if onchainKind d == Script && onchainVersion d == Just PlutusV3
          then Right ()
          else invalid "purpose-isolation requires a script with explicit version PlutusV3"
        if null allowed || length allowed /= length (nub allowed) || length allowed >= 6
          then invalid "purpose-isolation requires unique allowed purposes and at least one excluded purpose"
          else Right ()
        case reverse (onchainArgs d) of
          MkUalArgument "BuiltinData" AsData : _ -> Right ()
          _ -> invalid "purpose-isolation requires a raw BuiltinData context argument"
        let params = ["parameter" <> T.pack (show i) | i <- [0 .. length (onchainArgs d) - 2]]
            branches =
              [ "| ."
                  <> constructor
                  <> " "
                  <> fields
                  <> " => "
                  <> (if purpose `elem` allowed then "True" else "False")
              | (purpose, constructor, fields) <-
                  [ (Spend, "SpendingScript", "_ _")
                  , (Mint, "MintingScript", "_")
                  , (Withdraw, "RewardingScript", "_")
                  , (Publish, "CertifyingScript", "_ _")
                  , (Vote, "VotingScript", "_")
                  , (Propose, "ProposingScript", "_ _")
                  ]
              ]
            source =
              "∀ "
                <> T.unwords params
                <> " (ctx : CardanoLedgerApi.V3.ScriptContext),\n"
                <> "  (match ctx.scriptContextScriptInfo with\n    "
                <> T.intercalate "\n    " branches
                <> ") ∨\n"
                <> "  PlutusCore.UPLC.Utils.isUnsuccessful («"
                <> target
                <> "» "
                <> T.unwords params
                <> " (CardanoLedgerApi.IsData.Class.toLedgerData ctx))"
        Right
          p
            { propertyText =
                "The compiled script rejects every purpose outside {"
                  <> T.intercalate ", " (map purposeToText (sort allowed))
                  <> "}."
            , propertyBody = source
            }
