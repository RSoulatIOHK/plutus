# Generated purpose-isolation and acceptance properties

Build the generator from the Plutus checkout:

```sh
cabal build docusaurus-examples:exe:example-ual-purpose-isolation
```

Run the built generator in an output directory, passing a captured Cardano V3
checking-environment manifest as its sole argument. It writes `plutus.json`,
`assurance.json`, `source-types.json` and one checking context per property. The
source-types manifest binds the project's Haskell types to the exact blueprint
hash; it is local decoding metadata, separate from CIP-57 and UAL. Check that
bundle with:

```sh
cardano-blaster check plutus.json assurance.json --refresh-environment
```

The source generates two independent properties for each of the four scripts:
purpose isolation and existence of an accepted valid script context. The three
purpose-isolation claims for `spendingOnly`, `spendingAndMinting` and
`parameterizedSpending` should verify. The isolation claim for `uncheckedPurpose`
should be falsified with a counterexample replayed against its compiled UPLC.
The generated negative acceptance claims seek a counterexample with
`validScriptContext = true` and a confirmed UPLC replay. A falsification
establishes that the script accepts a valid context; an inconclusive check is
not an acceptance witness. The complete bundle can exit with code 1 because
the isolation claim for `uncheckedPurpose` is intentionally falsified.
That script checks its byte-string redeemer length and the transaction's range
and treasury fields, but omits purpose validation. Its blueprint redeemer
schema refers to `WitnessRedeemer`, a contract-defined newtype in `Types.hs`.
The source decoder uses the project's own `FromData` instance on the confirmed
wire value; this does not change the solver verdict.

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

The native parameter is universally quantified in both formal claims. The
acceptance template negates successful execution for every parameter and valid
context, then expects a confirmed counterexample; that witness establishes the
desired existential acceptance. The parameterized script accepts a spending
context when its native integer parameter is seven. The vulnerable script does
not rely on changing a formal claim to obtain a counterexample.

Each annotation expands to its own ordinary quantified Lean proposition in the
assurance document. Isolation requires actual evaluation failure for every valid
script context whose purpose is outside the explicitly supplied set; acceptance is
established by replaying a falsification of the generated universal rejection
claim. A solver model that fails replay does not count as an acceptance witness.
Neither template infers a purpose from the blueprint. All four blueprint entries
deliberately retain spending invocation metadata, including the script whose
isolation template also allows minting.

Isolation currently supports Plutus V3; acceptance supports V1, V2 and V3.
Both require a raw `BuiltinData` context argument. Unknown template
names/purposes, duplicate purposes, a set allowing all purposes, missing or
multiple scopes, functions, V1/V2 purpose isolation, V4 acceptance (until the
Lean ledger has a V4 context codec) and applied parameter bindings are
diagnosed. Exhaustion of the verification step bound does not count as
rejection. Both templates use the version-specific `validScriptContext`
predicate as their domain condition. V1 additionally quantifies the datum;
V2 quantifies the datum and redeemer required by that predicate.

The Auction example keeps its 31 checked scenario properties. A universal
purpose-isolation claim for that larger validator currently exceeds the
checker deadline, so it is not included in the Auction assurance bundle.
Cross-module template resolution is covered by the producer tests.
