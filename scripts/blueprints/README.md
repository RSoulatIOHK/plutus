Run `node scripts/blueprints/list-generators.js` from the project root to
discover UAL generators without building them. Each result includes the Cabal
invocation and a `properties` array. To list the properties for a source file:

```sh
node scripts/blueprints/list-generators.js \
  --source doc/docusaurus/static/code/Example/Ual/Auction/FormalSpec.hs |
  jq '.[].properties[]'
```

Print a copy-pasteable shell command per generator with
`node scripts/blueprints/list-generators.js | jq -r '.[].command'`.
Run each command from its result's `cwd`. `hasLocalEnvironment` reports whether
an `environment.json` file was found beside the executable's `main-is` source.
Discovery uses that file when present. An explicit `--environment FILE` takes
precedence and does not change the flag. With neither, the command omits
`--environment` and the generator creates an unpinned manifest.
Programmatic callers can use `argv` directly.

The CLI includes the selected or generated manifest as `environment.json`
in file and NDJSON output. A supplied file is copied byte for byte. For an
automatically generated manifest, each module passed to the generator may
declare a Lean module with `{-@ INCLUDE My.Lean.Module @-}`. The generator
sorts and deduplicates those names together with the default
`PlutusCore.UPLC.BlueprintEncoding.Assurance` import. These declarations
describe the unpinned manifest; the checker selects its own import profile.
Use `cardano-blaster check ... --refresh-environment` with an unpinned bundle.

`file` is relative to the result's `cwd`. The range covers the whole UAL
annotation, including its delimiters. Both lines and UTF-16 character offsets
are zero-based, and `end` is exclusive.

Use `kind` to decide what to show before compilation:

- `explicit`: `title` is the quoted description (`statement.text` in the assurance
  document), and `content` is the authored Lean (`statement.formal.source`).
- `template`: discovery omits `title` and `content`. Match the `id` to
  `assurance.json`'s `properties[].id` after generation and read the same two
  statement fields for the expanded description and Lean.

The array follows the annotation modules passed to the bundle generator, then
declaration order within each module, as in `assurance.json`. Discovery handles
literal lists of local or directly imported `$(ualModule)` bindings, including
qualified imports. For a computed list or an unresolved binding, the generator
is still listed with `properties: null` and a `propertyDiscoveryError`.
The generated assurance document supplies the runtime order in that case.

The source scanner is available as `propertyBlocks(file, text)` from
`./ual-properties.js`, so an editor can pass an unsaved document's text.

The extension can use two JSON Schemas for the CLI outputs:

- Validate the entire parsed discovery array against
  [list-generators.schema.json](list-generators.schema.json).
- With `--ndjson`, parse each line separately and validate it against
  [generator-artifact.schema.json](generator-artifact.schema.json). For JSON
  artifacts, parse the UTF-8 `content` string to inspect the inner document.
  To materialize the bundle, preserve that string exactly or hex-decode
  `base16` content. Check the generator's exit status for stream completion.
