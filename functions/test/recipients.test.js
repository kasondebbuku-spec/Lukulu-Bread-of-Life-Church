'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { rolesOf, hasAnyRole, selectRecipients, LEADER_ROLES } = require('../lib/recipients');

const users = [
  { uid: 'm1', roles: ['member'] },
  { uid: 'm2', role: 'member' }, // older profile with a single role
  { uid: 'p1', roles: ['pastor'] },
  { uid: 'p2', role: 'pastor' },
  { uid: 'f1', roles: ['finance', 'elder'] },
  { uid: 'o1', roles: ['oversight'] },
  { uid: 'a1', roles: ['admin'] },
  { uid: 'e1', roles: ['elder'] },
  { uid: 's1', roles: ['secretariat'] },
  { uid: 'h1', roles: ['hospitality'] },
  { uid: 'bad', roles: 'pastor' }, // damaged: roles is not a list
  { uid: 'empty', roles: [] },
  { uid: 'none' },
];

test('rolesOf reads a list, an older single role, or defaults to member', () => {
  assert.deepEqual(rolesOf({ roles: ['elder', 'finance'] }), ['elder', 'finance']);
  assert.deepEqual(rolesOf({ role: 'pastor' }), ['pastor']);
  assert.deepEqual(rolesOf({}), ['member']);
  assert.deepEqual(rolesOf(null), ['member']);
  assert.deepEqual(rolesOf({ roles: [] }), ['member']);
  assert.deepEqual(rolesOf({ roles: 'pastor' }), ['member']);
  assert.deepEqual(rolesOf({ roles: [1, null, 'elder'] }), ['elder']);
});

test('hasAnyRole matches any of several roles', () => {
  assert.equal(hasAnyRole({ roles: ['elder', 'finance'] }, ['pastor', 'finance']), true);
  assert.equal(hasAnyRole({ roles: ['elder'] }, ['pastor', 'finance']), false);
});

test('picks the people holding a role, including older profiles', () => {
  assert.deepEqual(selectRecipients(users, { roles: ['pastor'] }).sort(), ['p1', 'p2']);
});

test('a person with two roles is picked once', () => {
  const got = selectRecipients(users, { roles: ['finance', 'elder'] });
  assert.equal(got.filter((u) => u === 'f1').length, 1);
  assert.deepEqual(got.sort(), ['e1', 'f1']);
});

test('the finance audience is Finance, Oversight, Pastor and Admin, and nobody else', () => {
  const got = selectRecipients(users, { roles: ['finance', 'oversight', 'pastor', 'admin'] }).sort();
  assert.deepEqual(got, ['a1', 'f1', 'o1', 'p1', 'p2']);
  for (const never of ['m1', 'm2', 'e1', 's1', 'h1', 'bad', 'empty', 'none']) {
    assert.ok(!got.includes(never), never);
  }
});

test('the person who caused the change is left out', () => {
  assert.deepEqual(
    selectRecipients(users, { roles: ['pastor'], exclude: ['p1'] }).sort(),
    ['p2'],
  );
  assert.deepEqual(selectRecipients(users, { roles: ['pastor'], exclude: [undefined, ''] }).sort(), ['p1', 'p2']);
});

test('named people are picked by id', () => {
  assert.deepEqual(selectRecipients(users, { uids: ['m1', 'nobody'] }), ['m1']);
  assert.deepEqual(selectRecipients(users, { uids: ['m1'], exclude: ['m1'] }), []);
});

test('everyone means every account, minus the excluded', () => {
  const all = selectRecipients(users, { everyone: true });
  assert.equal(all.length, users.length);
  assert.ok(!selectRecipients(users, { everyone: true, exclude: ['m1'] }).includes('m1'));
});

test('a leaders-only announcement reaches leaders, not plain members or finance-only staff', () => {
  const got = selectRecipients(users, { roles: LEADER_ROLES }).sort();
  assert.deepEqual(got, ['a1', 'e1', 'f1', 'p1', 'p2', 's1']);
  assert.ok(!got.includes('m1') && !got.includes('o1') && !got.includes('h1'));
});

test('no rule means nobody is picked', () => {
  assert.deepEqual(selectRecipients(users, {}), []);
  assert.deepEqual(selectRecipients([], { everyone: true }), []);
  assert.deepEqual(selectRecipients([null, {}], { everyone: true }), []);
});
