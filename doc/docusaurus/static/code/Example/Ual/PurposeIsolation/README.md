# Generated purpose-isolation and acceptance properties

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

The source generates two independent properties for each of the four scripts:
purpose isolation and existence of an accepted typed context. The three
purpose-isolation claims for `spendingOnly`, `spendingAndMinting` and
`parameterizedSpending` should verify. The isolation claim for `uncheckedPurpose`
should be falsified with a counterexample replayed against its compiled UPLC.
The four acceptance claims should verify, demonstrating that none of these
scripts simply rejects every context. The complete bundle therefore
intentionally exits with code 1.

The source annotations are sufficient:

```haskell
{-@ PROPERTY [scope: spendingOnly]
    [template: purpose-isolation spending]
@-}
{-@ PROPERTY [scope: spendingOnly]
    [template: accepts-some-context]
@-}
{-@ PROPERTY [scope: spendingAndMinting]
    [template: purpose-isolation spending minting]
@-}
{-@ PROPERTY [scope: spendingAndMinting]
    [template: accepts-some-context]
@-}
```

The native parameter is universally quantified in the isolation claim and
existentially quantified in the separate acceptance claim. The vulnerable script checks the
transaction's range and treasury fields but omits purpose validation; it does not
rely on changing a formal claim to obtain a counterexample.

Each annotation expands to its own ordinary quantified Lean proposition in the
assurance document. Isolation requires actual evaluation failure for every typed
context whose purpose is outside the explicitly supplied set; acceptance requires
successful evaluation for at least one typed context, with no purpose restriction.
Neither template infers a purpose from the blueprint. All four blueprint entries
deliberately retain spending invocation metadata, including the script whose
isolation template also allows minting.

Both templates currently support Plutus V3 scripts and raw `BuiltinData` context
arguments. Isolation quantifies script parameters universally; acceptance
quantifies them existentially. Unknown template names/purposes, duplicate
purposes, a set allowing all purposes, missing or multiple scopes, functions,
V1/V2 scripts and applied parameter bindings are diagnosed. Exhaustion of the
verification step bound does not count as rejection. Typed contexts in this
property are not assumed to be ledger-valid transactions.

The Auction example keeps its 31 checked scenario properties. A universal
purpose-isolation claim for that larger validator currently exceeds the
checker deadline, so it is not included in the Auction assurance bundle.
Cross-module template resolution is covered by the producer tests.
