-- editorconfig-checker-disable-file
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE TypeApplications      #-}
{-# LANGUAGE TypeOperators         #-}
{-# LANGUAGE UndecidableInstances  #-}

{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE TypeFamilies          #-}
module PlutusIR.Test (
    module PlutusIR.Test,
    initialSrcSpan,
    topSrcSpan,
    rethrow,
) where

import PlutusPrelude
import Test.Tasty.Extras

import Control.Exception
import Control.Lens hiding (op, transform)
import Control.Monad.Except
import Control.Monad.Morph
import Control.Monad.Reader as Reader

import PlutusCore qualified as PLC
import PlutusCore.Builtin qualified as PLC
import PlutusCore.Compiler qualified as PLC
import PlutusCore.Name
import PlutusCore.Pretty
import PlutusCore.Pretty qualified as PLC
import PlutusCore.Quote (runQuoteT)
import PlutusCore.Test
import PlutusIR as PIR
import PlutusIR.Compiler as PIR
import PlutusIR.Parser (Parser, parse)
import PlutusIR.TypeCheck
import System.FilePath (joinPath, (</>))

import Data.Text qualified as T
import Data.Text.IO qualified as T

import PlutusCore.Error (ParserErrorBundle)

import Prettyprinter
import Prettyprinter.Render.Text

instance ( PLC.Pretty (PLC.SomeTypeIn uni), PLC.GEq uni, PLC.Typecheckable uni fun
         , PLC.Closed uni, uni `PLC.Everywhere` PrettyConst, Pretty fun, Pretty a
         , Typeable a, Ord a, Default (PLC.CostingPart uni fun)
         ) => ToTPlc (PIR.Program TyName Name uni fun a) uni fun where
    toTPlc = asIfThrown . fmap void . compileWithOpts id

instance ( PLC.Pretty (PLC.SomeTypeIn uni), PLC.GEq uni, PLC.Typecheckable uni fun
         , PLC.Closed uni, uni `PLC.Everywhere` PrettyConst, Pretty fun, Pretty a
         , Typeable a, Ord a, Default (PLC.CostingPart uni fun)
         ) => ToUPlc (PIR.Program TyName Name uni fun a) uni fun where
    toUPlc t = do
        p' <- toTPlc t
        pure $ PLC.runQuote $ flip runReaderT PLC.defaultCompilationOpts $ PLC.compileProgram  p'

-- | Adapt an computation that keeps its errors in an 'Except' into one that looks as if it caught them in 'IO'.
asIfThrown
    :: Exception e
    => Except e a
    -> ExceptT SomeException IO a
asIfThrown = withExceptT SomeException . hoist (pure . runIdentity)

compileWithOpts
    :: (PLC.GEq uni, PLC.Typecheckable uni fun, Ord a, PLC.Pretty fun, PLC.Closed uni, PLC.Pretty (PLC.SomeTypeIn uni), uni `PLC.Everywhere` PLC.PrettyConst, PLC.Pretty a, Default (PLC.CostingPart uni fun))
    => (CompilationCtx uni fun a -> CompilationCtx uni fun a)
    -> Program TyName Name uni fun a
    -> Except (PIR.Error uni fun (PIR.Provenance a)) (PLC.Program TyName Name uni fun (PIR.Provenance a))
compileWithOpts optsMod pir = do
    tcConfig <- PLC.getDefTypeCheckConfig noProvenance
    let pirCtx = optsMod (toDefaultCompilationCtx tcConfig)
    flip runReaderT pirCtx $ runQuoteT $ do
        compiled <- compileProgram pir
        -- PLC errors are parameterized over PLC.Terms, whereas PIR errors over PIR.Terms and as such, these prism errors cannot be unified.
        -- We instead run the ExceptT, collect any PLC error and explicitly lift into a PIR error by wrapping with PIR._PLCError
        plcConcrete <- runExceptT $ void $ PLC.inferTypeOfProgram tcConfig compiled
        liftEither $ first (view (re _PLCError)) plcConcrete
        pure compiled

withGoldenFileM :: String -> (T.Text -> IO T.Text) -> TestNested
withGoldenFileM name op = do
    dir <- currentDir
    let testFile = dir </> name
        goldenFile = dir </> name ++ ".golden"
    return $ goldenVsTextM name goldenFile (op =<< T.readFile testFile)
    where currentDir = joinPath <$> ask

goldenPir :: Pretty b => (a -> b) -> Parser a -> String -> TestNested
goldenPir op = goldenPirM (return . op)

goldenPirDoc :: (a -> Doc ann) -> Parser a -> String -> TestNested
goldenPirDoc op = goldenPirDocM (return . op)

goldenPirM :: forall a b . Pretty b => (a -> IO b) -> Parser a -> String -> TestNested
goldenPirM op parser name = withGoldenFileM name parseOrError
    where
        parseOrError :: T.Text -> IO T.Text
        parseOrError =
            let parseTxt :: T.Text -> Either ParserErrorBundle a
                parseTxt txt = runQuoteT $ parse parser name txt
            in
            either (return . display) (fmap display . op)
                         . parseTxt


goldenPirMUnique :: forall a b . (PrettyPlc b) => (a -> IO b) -> Parser a -> String -> TestNested
goldenPirMUnique op parser name = withGoldenFileM name parseOrError
    where
        parseOrError :: T.Text -> IO T.Text
        parseOrError =
            let parseTxt :: T.Text -> Either ParserErrorBundle a
                parseTxt txt = runQuoteT $ parse parser name txt
            in
            either (return . display) (fmap (render . prettyPlcReadableDef) . op)
                         . parseTxt

goldenPirDocM :: forall a ann. (a -> IO (Doc ann)) -> Parser a -> String -> TestNested
goldenPirDocM op parser name = withGoldenFileM name parseOrError
    where
        parseOrError :: T.Text -> IO T.Text
        parseOrError =
            let parseTxt :: T.Text -> Either ParserErrorBundle a
                parseTxt txt = runQuoteT $ parse parser name txt
            in
            either (return . display) (fmap (renderStrict . layoutPretty defaultLayoutOptions) . op)
                         . parseTxt

ppThrow :: PrettyPlc a => ExceptT SomeException IO a -> IO T.Text
ppThrow = fmap render . rethrow . fmap prettyPlcClassicDebug

ppCatch :: PrettyPlc a => ExceptT SomeException IO a -> IO T.Text
ppCatch value = render <$> (either (pretty . show) prettyPlcClassicDebug <$> runExceptT value)

goldenPlcFromPir ::
    ToTPlc a PLC.DefaultUni PLC.DefaultFun =>
    Parser a -> String -> TestNested
goldenPlcFromPir = goldenPirM (\ast -> ppThrow $ do
                                p <- toTPlc ast
                                withExceptT @_ @PLC.FreeVariableError toException $ traverseOf PLC.progTerm PLC.deBruijnTerm p)

goldenPlcFromPirScott ::
    (Ord a, Typeable a, Pretty a, prog ~ PIR.Program TyName Name PLC.DefaultUni PLC.DefaultFun a) =>
    Parser prog -> String -> TestNested
goldenPlcFromPirScott = goldenPirM (\ast -> ppThrow $ do
                                p <- asIfThrown . fmap void . compileWithOpts (set (PIR.ccOpts . PIR.coDatatypes . PIR.dcoStyle) ScottEncoding) $ ast
                                withExceptT @_ @PLC.FreeVariableError toException $ traverseOf PLC.progTerm PLC.deBruijnTerm p)

goldenNamedUPlcFromPir ::
    ToUPlc a PLC.DefaultUni PLC.DefaultFun =>
    Parser a -> String -> TestNested
goldenNamedUPlcFromPir = goldenPirM $ ppThrow . toUPlc

goldenPlcFromPirCatch ::
    ToTPlc a PLC.DefaultUni PLC.DefaultFun =>
    Parser a -> String -> TestNested
goldenPlcFromPirCatch = goldenPirM (\ast -> ppCatch $ do
                                           p <- toTPlc ast
                                           withExceptT @_ @PLC.FreeVariableError toException $ traverseOf PLC.progTerm PLC.deBruijnTerm p)

goldenEvalPir ::
    ToUPlc a PLC.DefaultUni PLC.DefaultFun =>
    Parser a -> String -> TestNested
goldenEvalPir = goldenPirM (\ast -> ppThrow $ runUPlc [ast])

goldenTypeFromPir ::
    forall a. (Pretty a, Typeable a) =>
    a ->
    Parser (Term TyName Name PLC.DefaultUni PLC.DefaultFun a) ->
    String ->
    TestNested
goldenTypeFromPir x =
    goldenPirM $ \ast -> ppThrow $
        withExceptT (toException :: PIR.Error PLC.DefaultUni PLC.DefaultFun a -> SomeException) $
            runQuoteT $ do
                tcConfig <- getDefTypeCheckConfig x
                inferType tcConfig ast

goldenTypeFromPirCatch ::
    forall a. (Pretty a, Typeable a) =>
    a ->
    Parser (Term TyName Name PLC.DefaultUni PLC.DefaultFun a) ->
    String ->
    TestNested
goldenTypeFromPirCatch x =
    goldenPirM $ \ast -> ppCatch $
        withExceptT (toException :: PIR.Error PLC.DefaultUni PLC.DefaultFun a -> SomeException) $
            runQuoteT $ do
                tcConfig <- getDefTypeCheckConfig x
                inferType tcConfig ast
