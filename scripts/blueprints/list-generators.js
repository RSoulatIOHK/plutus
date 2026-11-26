// Static discovery for Plutus UAL examples. Uses only Node's standard library.
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { parseArgs } = require('node:util');

const { generatorProperties, withoutComments } = require('./ual-properties');

const usage = 'Usage: node scripts/blueprints/list-generators.js [ROOT | PACKAGE.cabal] [--source FILE.hs] [--environment FILE.json]\nROOT defaults to the current directory.';

function shellQuote(arg) {
  if (arg.length && !/[^a-zA-Z0-9_./:+-]/.test(arg)) return arg;
  return "'" + arg.replaceAll("'", "'\\''") + "'";
}

function packageFiles(root) {
  if (!fs.statSync(root).isDirectory()) {
    if (root.endsWith('.cabal')) return [root];
    throw new Error('Expected a directory or a .cabal file: ' + root);
  }

  const skipped = new Set(['dist', 'dist-newstyle', 'node_modules', 'tasty-investigate']);
  const files = [];
  function scan(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const file = path.join(dir, entry.name);
      if (entry.isFile() && entry.name.endsWith('.cabal')) files.push(file);
      else if (entry.isDirectory() && !entry.name.startsWith('.') && !skipped.has(entry.name)) scan(file);
    }
  }
  scan(root);
  return files.sort();
}

function listGenerators(packageFile, selectedSource, environment) {
  const dir = path.dirname(path.resolve(packageFile));
  let cwd = dir;
  while (!fs.existsSync(path.join(cwd, 'cabal.project'))) {
    const parent = path.dirname(cwd);
    if (parent === cwd) { cwd = dir; break; }
    cwd = parent;
  }
  const cabal = fs.readFileSync(packageFile, 'utf8').replace(/^[ \t]*--.*$|[ \t]+--.*$/gm, '');
  const packageName = /^name:[ \t]*(\S+)/mi.exec(cabal)?.[1];
  if (!packageName) throw new Error('Missing package name in ' + packageFile);

  const entries = [];
  for (const stanza of cabal.split(/\n(?=[^\s])/)) {
    const exe = /^executable[ \t]+(\S+)/i.exec(stanza)?.[1];
    if (!exe) continue;
    // Only unconditional fields declared directly on the executable are used.
    const fields = new Map();
    let field;
    const lines = stanza.split(/\r?\n/).slice(1).filter(line => line.trim());
    const indent = Math.min(...lines.map(line => line.search(/\S/)));
    for (const line of lines) {
      if (line.search(/\S/) === indent) {
        const match = /^([\w-]+):\s*(.*)$/.exec(line.trim());
        field = match?.[1].toLowerCase();
        if (field) fields.set(field, match[2]);
      } else if (field) fields.set(field, fields.get(field) + ' ' + line.trim());
    }
    const main = fields.get('main-is');
    if (!main) continue;
    const roots = (fields.get('hs-source-dirs') || '.').split(/[\s,]+/).filter(Boolean);
    const resolveFile = name => roots.map(root => path.resolve(dir, root, name)).find(f => fs.existsSync(f));
    const mainFile = resolveFile(main);
    if (!mainFile) continue;
    const mainText = fs.readFileSync(mainFile, 'utf8');
    const hs = withoutComments(mainText);
    const binding = /^main[ \t]*=/m.exec(hs);
    if (!binding) continue;
    const mainBody = hs.slice(binding.index + binding[0].length).split(/\n(?=\S)/, 1)[0];
    if (!/\bdefaultMainInterfaceBundle(?:WithBindings)?\b/.test(mainBody)) continue;
    const modules = (fields.get('other-modules') || '').split(/[\s,]+/).filter(Boolean);
    const moduleFiles = new Map(modules.map(name => [name, resolveFile(name.replaceAll('.', '/') + '.hs')])
      .filter(([, file]) => file));
    const sources = [mainFile, ...moduleFiles.values()];
    if (selectedSource && !sources.includes(path.resolve(selectedSource))) continue;

    const target = packageName + ':exe:' + exe;
    const localEnv = path.join(path.dirname(mainFile), 'environment.json');
    const hasLocalEnvironment = fs.statSync(localEnv, { throwIfNoEntry: false })?.isFile() === true;
    const env = environment || (hasLocalEnvironment ? localEnv : null);
    const argv = ['cabal', 'run', '-v0', target, '--', '--ndjson'];
    if (env) argv.push('--environment', path.relative(cwd, env));
    const mainSource = { file: path.relative(cwd, mainFile), text: mainText };
    const moduleSources = new Map([...moduleFiles].map(([name, file]) =>
      [name, { file: path.relative(cwd, file), text: fs.readFileSync(file, 'utf8') }]));
    entries.push({
      target, cwd, main: path.relative(cwd, mainFile),
      sources: sources.map(f => path.relative(cwd, f)),
      ...generatorProperties(mainSource, mainBody, moduleSources),
      hasLocalEnvironment,
      argv,
      command: argv.map(shellQuote).join(' '),
    });
  }
  return entries;
}

try {
  const { values, positionals } = parseArgs({ allowPositionals: true, options: {
    source: { type: 'string' }, environment: { type: 'string' }, help: { type: 'boolean' },
  } });
  if (values.help) console.log(usage);
  else {
    if (positionals.length > 1) throw new Error(usage);
    if (values.environment && !fs.statSync(values.environment).isFile()) throw new Error('Expected an environment file');
    const entries = packageFiles(positionals[0] ?? '.').flatMap(file =>
      listGenerators(file, values.source, values.environment));
    console.log(JSON.stringify(entries, null, 2));
  }
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
