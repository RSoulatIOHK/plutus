{-# LANGUAGE OverloadedStrings #-}

module Ual.TemplatesSpec (tests) where

import Data.Either (isLeft)
import Data.Text (Text)
import Data.Text qualified as T
import PlutusTx.Blueprint.PlutusVersion (PlutusVersion (..))
import PlutusTx.Ual.Error (UalError)
import PlutusTx.Ual.Parser (moduleUalFromSource)
import PlutusTx.Ual.Syntax
import PlutusTx.Ual.Templates (expandPropertyTemplates)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertFailure, testCase, (@?=))
import Prelude

source :: Text -> Text
source options =
  T.unlines
    [ "module Spec where"
    , "{-@ ONCHAIN [version: PlutusV3] [steps: 100, semantics: E] auction :: Integer -> BuiltinData -> BuiltinUnit @-}"
    , "{-@ PROPERTY " <> options <> " @-}"
    ]

parse :: Text -> Either UalError ModuleUal
parse = moduleUalFromSource (UalModuleName "Spec") . source

tests :: TestTree
tests =
  testGroup "property templates" $
    [ testCase "short form generates a complete universally quantified claim" $
        case parse "[scope: auction] [template: purpose-isolation spending]" of
          Left e -> assertFailure (show e)
          Right m -> case expandPropertyTemplates [m] of
            Left es -> assertFailure (show es)
            Right [expanded] -> case ualProperties expanded of
              [p] -> do
                propertyName p @?= "auction_purpose_isolation"
                propertyScope p @?= ["auction"]
                assertBool
                  "all contexts and parameters are quantified"
                  ("∀ parameter0 (ctx : CardanoLedgerApi.V3.ScriptContext)" `T.isInfixOf` propertyBody p)
                assertBool
                  "actual script failure, not negated success"
                  ("isUnsuccessful («auction» parameter0" `T.isInfixOf` propertyBody p)
                assertBool
                  "spending is excluded from the rejection domain"
                  (".SpendingScript _ _ => True" `T.isInfixOf` propertyBody p)
                assertBool
                  "governance purposes are covered"
                  (".VotingScript _ => False" `T.isInfixOf` propertyBody p)
              _ -> assertFailure "expected one generated property"
            _ -> assertFailure "expected one module"
    , testCase "multiple allowed purposes are template arguments" $
        case parse "[scope: auction] [template: purpose-isolation spending minting]" of
          Left e -> assertFailure (show e)
          Right m -> case expandPropertyTemplates [m] of
            Left es -> assertFailure (show es)
            Right [expanded] ->
              assertBool
                "minting is also allowed"
                (any (T.isInfixOf ".MintingScript _ => True" . propertyBody) (ualProperties expanded))
            _ -> assertFailure "expected one module"
    , testCase "acceptance is generated as an independent existential property" $
        case moduleUalFromSource (UalModuleName "Spec") $
          T.unlines
            [ "module Spec where"
            , "{-@ ONCHAIN [version: PlutusV3] [steps: 100, semantics: E] auction :: Integer -> BuiltinData -> BuiltinUnit @-}"
            , "{-@ PROPERTY [scope: auction] [template: purpose-isolation spending] @-}"
            , "{-@ PROPERTY [scope: auction] [template: accepts-some-context] @-}"
            ] of
          Left e -> assertFailure (show e)
          Right m -> case expandPropertyTemplates [m] of
            Left es -> assertFailure (show es)
            Right [expanded] -> case ualProperties expanded of
              [isolation, acceptance] -> do
                propertyName isolation @?= "auction_purpose_isolation"
                propertyName acceptance @?= "auction_accepts_some_context"
                assertBool
                  "isolation remains a universal rejection claim"
                  ("∀ parameter0 (ctx : CardanoLedgerApi.V3.ScriptContext)" `T.isInfixOf` propertyBody isolation)
                assertBool
                  "acceptance has its own existential over parameters and typed context"
                  ( "Exists (fun parameter0 =>\n∃ (ctx : CardanoLedgerApi.V3.ScriptContext)"
                      `T.isInfixOf` propertyBody acceptance
                  )
                assertBool
                  "acceptance checks successful compiled execution"
                  ("isSuccessful («auction» parameter0" `T.isInfixOf` propertyBody acceptance)
                assertBool
                  "acceptance has no purpose-isolation premise"
                  (not ("scriptContextScriptInfo" `T.isInfixOf` propertyBody acceptance))
              _ -> assertFailure "expected two independent generated properties"
            _ -> assertFailure "expected one module"
    , testCase "acceptance without script parameters quantifies only the context" $
        case parse "[scope: auction] [template: accepts-some-context]" of
          Left e -> assertFailure (show e)
          Right m ->
            let scripts = [d {onchainArgs = [MkUalArgument "BuiltinData" AsData]} | d <- ualOnchain m]
             in case expandPropertyTemplates [m {ualOnchain = scripts}] of
                  Left es -> assertFailure (show es)
                  Right [expanded] -> case ualProperties expanded of
                    [p] -> do
                      assertBool
                        "single existential context binder"
                        ("∃ (ctx : CardanoLedgerApi.V3.ScriptContext)" `T.isInfixOf` propertyBody p)
                      assertBool
                        "no phantom parameter binder"
                        (not ("parameter0" `T.isInfixOf` propertyBody p))
                    _ -> assertFailure "expected one generated property"
                  _ -> assertFailure "expected one module"
    , testCase "template target may be imported from another module" $
        case parse "[scope: auction] [template: purpose-isolation spending]" of
          Left e -> assertFailure (show e)
          Right m ->
            assertBool "detached target resolves across modules" $
              not $
                isLeft $
                  expandPropertyTemplates
                    [ m {ualOnchain = []}
                    , (emptyModuleUal (UalModuleName "OnChain")) {ualOnchain = ualOnchain m}
                    ]
    , testCase "functions and older calling conventions are rejected" $
        case parse "[scope: auction] [template: purpose-isolation spending]" of
          Left e -> assertFailure (show e)
          Right m ->
            mapM_
              ( \change ->
                  assertBool "unsupported target diagnosed" $
                    isLeft $
                      expandPropertyTemplates [m {ualOnchain = map change (ualOnchain m)}]
              )
              [ (\d -> d {onchainKind = Function})
              , (\d -> d {onchainVersion = Just PlutusV2})
              , (\d -> d {onchainVersion = Nothing})
              , (\d -> d {onchainArgs = [MkUalArgument "ScriptContext" AsData]})
              ]
    ]
      <> [ testCase (T.unpack label) $
             assertBool "malformed template rejected" (isLeft (parse options))
         | (label, options) <-
             [ ("missing scope", "[template: purpose-isolation spending]")
             , ("ambiguous scope", "[scope: auction helper] [template: purpose-isolation spending]")
             , ("missing purpose", "[scope: auction] [template: purpose-isolation]")
             , ("unknown purpose", "[scope: auction] [template: purpose-isolation spendng]")
             , ("duplicate purpose", "[scope: auction] [template: purpose-isolation spending spending]")
             , ("unknown template", "[scope: auction] [template: purpose-isolaton spending]")
             , ("acceptance takes no arguments", "[scope: auction] [template: accepts-some-context spending]")
             ,
               ( "duplicate template"
               , "[scope: auction] [template: purpose-isolation spending] [template: purpose-isolation minting]"
               )
             ,
               ( "no rejected domain"
               , "[scope: auction] [template: purpose-isolation spending minting rewarding certifying voting proposing]"
               )
             ,
               ( "trailing user proposition"
               , "[scope: auction] [template: purpose-isolation spending] p \"text\" : True"
               )
             ]
         ]
