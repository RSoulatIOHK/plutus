'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { generatorProperties, propertyBlocks } = require('./ual-properties');

test('property order follows the bundle argument, including detached and unused specs', () => {
  const spec = (name, ids) => ({
    file: name + '.hs',
    text: [...ids.map(id => `{-@ PROPERTY ${id} "example" : True @-}`),
      'annotations = $(ualModule)'].join('\n'),
  });
  const modules = new Map([
    ['First', spec('First', ['a'])],
    ['Second', spec('Second', ['z', 'b'])],
    ['Unused', spec('Unused', ['unused'])],
  ]);
  const main = { file: 'Main.hs', text: [
    'import First (annotations)', 'import qualified Second as S', 'import Unused hiding (annotations)',
    '{-@ PROPERTY [template: accepts-some-context, scope: lock] @-}', 'local = $(ualModule)',
  ].join('\n') };
  const body = 'defaultMainInterfaceBundle preamble "" [S.annotations, local, annotations] blueprint';
  assert.deepEqual(generatorProperties(main, body, modules).properties.map(p => [p.id, p.file]), [
    ['z', 'Second.hs'], ['b', 'Second.hs'], ['lock_accepts_some_context', 'Main.hs'], ['a', 'First.hs'],
  ]);
  assert.equal(generatorProperties(main, body.replace('[S.annotations, local, annotations]', 'compute specs'), modules).properties, null);
});

test('complete block ranges use UTF-16 columns, including CRLF and same-line blocks', () => {
  const block = '{-@ PROPERTY\r\n  [scope: v] 7-a "😀" : True @-}';
  const template = '{-@ PROPERTY [scope: v] [template: purpose-isolation spending] @-}';
  const prefix = '😀  ';
  const text = `{-@ PREDICATE ignored @-}\r\n${prefix}${block} ${template}`;
  const [explicit, generated] = propertyBlocks('Spec.hs', text);
  const endColumn = block.split('\r\n')[1].length;
  assert.deepEqual(explicit, { id: '7-a', kind: 'explicit', title: '😀', content: 'True', file: 'Spec.hs', range: {
    start: { line: 1, character: 4 }, end: { line: 2, character: endColumn },
  } });
  assert.deepEqual(generated, { id: 'v_purpose_isolation', kind: 'template', file: 'Spec.hs', range: {
    start: { line: 2, character: endColumn + 1 }, end: { line: 2, character: endColumn + 1 + template.length },
  } });
  assert.throws(() => propertyBlocks('Spec.hs', '{-@ PROPERTY unfinished'), /Unclosed UAL block/);
});

test('explicit descriptions fold whitespace while Lean retains quotes, colons and layout', () => {
  const body = '∀ (x : String),\n    x = "a:b" → True';
  const [property] = propertyBlocks('Spec.hs', `{-@ PROPERTY example "Case:\n  a   or b" :\n  ${body}\n@-}`);
  assert.equal(property.title, 'Case: a or b');
  assert.equal(property.content, body);
});
