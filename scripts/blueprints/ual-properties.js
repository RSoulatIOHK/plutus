// Source discovery shared with editor clients. All paths are relative to the
// generator's cwd; ranges follow VS Code (zero-based UTF-16, end exclusive).
'use strict';

function parseProperty(body) {
  const options = new Map();
  let rest = body.trimStart();
  while (rest.startsWith('[')) {
    const end = rest.indexOf(']');
    if (end < 0) return null;
    for (const pair of rest.slice(1, end).split(',')) {
      const option = /^\s*(scope|template)\s*:\s*(.*?)\s*$/s.exec(pair);
      if (!option || options.has(option[1])) return null;
      options.set(option[1], option[2]);
    }
    rest = rest.slice(end + 1).trimStart();
  }
  if (!options.has('template')) {
    // The UAL parser takes the first closing quote, folds whitespace in the
    // description and trims only the outer whitespace of the opaque Lean body.
    const match = /^([A-Za-z0-9_-]+)\s*"([^"]*)"\s*:([\s\S]*)$/.exec(rest);
    if (!match) return null;
    const title = match[2].trim().replace(/\s+/g, ' ');
    const content = match[3].trim();
    if (!title || !content) return null;
    return { id: match[1], kind: 'explicit', title, content };
  }
  const scope = options.get('scope');
  if (rest || !scope || !/^[A-Za-z0-9_-]+$/.test(scope)) return null;
  const template = options.get('template').split(/\s+/);
  if (template.length === 1 && template[0] === 'accepts-some-context') {
    return { id: scope + '_accepts_some_context', kind: 'template' };
  }
  if (template.length > 1 && template[0] === 'purpose-isolation') {
    return { id: scope + '_purpose_isolation', kind: 'template' };
  }
  return null;
}

// Mirror PlutusTx.Ual.Lexer: scan *all* raw UAL blocks in order, so text
// inside a PREDICATE or ONCHAIN block cannot become a second declaration.
function propertyBlocks(file, text) {
  const properties = [];
  let line = 0;
  let lineStart = 0;
  let nextBreak = text.indexOf('\n');
  function position(offset) {
    while (nextBreak >= 0 && nextBreak < offset) {
      line++;
      lineStart = nextBreak + 1;
      nextBreak = text.indexOf('\n', lineStart);
    }
    return { line, character: offset - lineStart };
  }

  let cursor = 0;
  while (true) {
    const start = text.indexOf('{-@', cursor);
    if (start < 0) return properties;
    const close = text.indexOf('@-}', start + 3);
    if (close < 0) throw new Error(`Unclosed UAL block in ${file} at line ${position(start).line + 1}`);
    cursor = close + 3;
    const body = text.slice(start + 3, close).trimStart();
    const keyword = /^PROPERTY(?=\s|$)/.exec(body);
    if (!keyword) continue;
    const property = parseProperty(body.slice(keyword[0].length));
    if (!property) throw new Error(`Unrecognized PROPERTY in ${file} at line ${position(start).line + 1}`);
    properties.push({ ...property, file, range: { start: position(start), end: position(cursor) } });
  }
}

function withoutComments(text) {
  return text.replace(/{-[\s\S]*?-}|--[^\n]*/g, ' ');
}

// Recognize the direct application used by the examples. In particular, match
// the third argument rather than picking an arbitrary list in main.
function moduleArguments(mainBody) {
  const calls = [...mainBody.matchAll(/\bdefaultMainInterfaceBundle(?:WithBindings)?\b/g)];
  if (calls.length !== 1) return null;
  const args = mainBody.slice(calls[0].index + calls[0][0].length);
  const atom = /\s*(?:"(?:\\.|[^"\\])*"|\$?\([^()]*\)|[\w.']+)/y;
  if (!atom.test(args) || !atom.test(args)) return null;
  const list = /^\s*\[([^\]]*)\]/.exec(args.slice(atom.lastIndex));
  if (!list) return null;
  if (!list[1].trim()) return [];
  const refs = list[1].split(',').map(s => s.trim());
  return refs.every(s => /^(?:[A-Z][\w']*\.)*[a-z_][\w']*$/.test(s)) ? refs : null;
}

function spliceBindings(code) {
  return new Set([...code.matchAll(/^([a-z_][\w']*)\s*=\s*\$\(\s*(?:[A-Z][\w']*\.)*ualModule\s*\)[ \t]*\r?$/gm)]
    .map(match => match[1]));
}

// Resolve local and directly imported splices. Restrict candidates to the
// actual imports; other-modules can contain unused specifications.
function importedBindings(code, sources) {
  const imports = [];
  const decl = /^import\s+(qualified\s+)?([A-Z][\w.']*)([ \t]+qualified\b)?(?:\s+as\s+([A-Z][\w.']*))?(?:\s+(hiding))?(?:\s*\(([^()]*)\))?/gm;
  for (const m of code.matchAll(decl)) {
    const source = sources.get(m[2]);
    if (!source) continue;
    imports.push({ source, qualifier: m[4] || m[2], qualified: Boolean(m[1] || m[3]),
      hiding: Boolean(m[5]), names: m[6]?.split(',').map(s => s.trim()) });
  }
  return imports;
}

// modules contains the resolved Cabal other-modules, keyed by module name.
// Never substitute Cabal order for producer order when a list is computed.
function generatorProperties(main, mainBody, modules) {
  const refs = moduleArguments(mainBody);
  if (!refs) return { properties: null, propertyDiscoveryError: 'Cannot resolve the annotation-module list in main' };
  const code = withoutComments(main.text);
  const locals = spliceBindings(code);
  const imports = importedBindings(code, modules);
  const properties = [];
  for (const ref of refs) {
    const names = ref.split('.');
    const binding = names.pop();
    const qualifier = names.join('.');
    const candidates = new Set();
    if (!qualifier && locals.has(binding)) candidates.add(main);
    for (const imp of imports) {
      if (qualifier ? imp.qualifier !== qualifier : imp.qualified) continue;
      if (imp.names && imp.names.includes(binding) === imp.hiding) continue;
      if (spliceBindings(withoutComments(imp.source.text)).has(binding)) candidates.add(imp.source);
    }
    if (candidates.size !== 1) {
      return { properties: null, propertyDiscoveryError: `Cannot resolve annotation binding ${ref}` };
    }
    const [source] = candidates;
    try {
      properties.push(...propertyBlocks(source.file, source.text));
    } catch (error) {
      return { properties: null, propertyDiscoveryError: error.message };
    }
  }
  return { properties };
}

module.exports = { propertyBlocks, generatorProperties, withoutComments };
