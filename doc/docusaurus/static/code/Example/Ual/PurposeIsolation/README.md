# Generated purpose-isolation properties

Build the generator from the Plutus checkout:

```sh
cabal build docusaurus-examples:exe:example-ual-purpose-isolation
```

Run the built generator in an output directory, passing a captured Cardano V3
checking-environment manifest as its sole argument. It writes `plutus.json`,
`assurance.json` and one checking context per property. Check that bundle with:

```sh
cardano-blaster check plutus.json assurance.json --refresh-environment
```

Five properties should verify: the three generated purpose-isolation claims for
`spendingOnly`, `spendingAndMinting` and `parameterizedSpending`, and the positive
acceptance claims for spending and minting. The generated claim for `uncheckedPurpose` should be
falsified with a counterexample replayed against its compiled UPLC. Consequently,
checking the complete demonstration bundle intentionally exits with code 1.

The source annotations are sufficient:

```haskell
{-@ PROPERTY [scope: spendingOnly]
    [template: purpose-isolation spending]
@-}
{-@ PROPERTY [scope: spendingAndMinting]
    [template: purpose-isolation spending minting]
@-}
```

The native parameter is universally quantified. The vulnerable script checks the
transaction's range and treasury fields but omits purpose validation; it does not
rely on changing a formal claim to obtain a counterexample.

Each template expands to an ordinary quantified Lean proposition in the assurance
document. It requires actual evaluation failure for every typed context whose
purpose is outside the explicitly supplied set. It does not infer that set from
the blueprint. All four blueprint entries deliberately retain spending
invocation metadata, including the script whose template also allows minting.

The template currently supports Plutus V3 scripts, raw `BuiltinData` context
arguments and universal parameters. Unknown template names/purposes, duplicate
purposes, a set allowing all purposes, missing or multiple scopes, functions,
V1/V2 scripts and applied parameter bindings are diagnosed. Exhaustion of the
verification step bound does not count as rejection. Typed contexts in this
property are not assumed to be ledger-valid transactions.

The Auction example keeps its 31 checked scenario properties. A universal
purpose-isolation claim for that larger validator currently exceeds the
checker deadline, so it is not included in the Auction assurance bundle.
Cross-module template resolution is covered by the producer tests.
