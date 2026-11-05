# Generated detection of total rejection

`Main.hs` contains a Plinth V3 validator that decodes the script purpose from
the context and demands that its constructor tag be both `1` and `0`. No
context can make it succeed. Decoding failures also reject; the validator is
not a constant `traceError`.

The single source annotation, `[template: accepts-some-context]`, makes the
Plutus producer generate the blueprint, assurance proposition and checking
context. The proposition says that every valid V3 context is rejected and
expects a falsification with a compiled-UPLC acceptance witness. Since this
script rejects everything, successful verification of the universal negative
claim is an **unmet expectation**: the checker exits 1. That result detects
total rejection within the declared 1,000-step CEK bound.

From the Plutus repository root, build the producer with GHC 9.6 and run it
in an empty output directory with a captured `environment.json`:

```sh
cabal build docusaurus-examples:exe:example-ual-total-rejection
cd /path/to/output
/path/to/example-ual-total-rejection environment.json
cardano-blaster check plutus.json assurance.json --refresh-environment
```

The companion `cardano-blaster` fixture contains the generated JSON and runs
the same check in its native integration suite. This is an end-to-end Plinth
generator case; no Lean property is hand-authored in the fixture.
