'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { deliver, tokensFor, chunks } = require('../lib/send');

// A tiny stand-in for Firestore's `push_tokens` collection.
function fakeDb(rows) {
  const deleted = [];
  const queries = [];
  return {
    deleted,
    queries,
    collection(name) {
      assert.equal(name, 'push_tokens');
      return {
        where(field, op, values) {
          assert.equal(field, 'uid');
          assert.equal(op, 'in');
          assert.ok(values.length <= 30, 'Firestore allows at most 30 values in an "in" query');
          queries.push(values);
          return {
            async get() {
              const docs = rows
                .filter((r) => values.includes(r.uid))
                .map((r) => ({ id: r.token, ref: { delete: async () => deleted.push(r.token) } }));
              return { forEach: (f) => docs.forEach(f) };
            },
          };
        },
      };
    },
  };
}

function fakeMessaging(failures = {}) {
  const calls = [];
  return {
    calls,
    async sendEachForMulticast(payload) {
      calls.push(payload);
      const responses = payload.tokens.map((t) =>
        failures[t] ? { success: false, error: { code: failures[t] } } : { success: true });
      return { successCount: responses.filter((r) => r.success).length, responses };
    },
  };
}

test('chunks splits a list into groups of a given size', () => {
  assert.deepEqual(chunks([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]]);
  assert.deepEqual(chunks([], 3), []);
});

test('sends nothing, and asks for nothing, when there is nobody to tell', async () => {
  const db = fakeDb([]);
  const messaging = fakeMessaging();
  assert.deepEqual(await deliver({ db, messaging }, [], { title: 't', body: 'b' }), { devices: 0, sent: 0, removed: 0 });
  assert.deepEqual(await deliver({ db, messaging }, undefined, { title: 't', body: 'b' }), { devices: 0, sent: 0, removed: 0 });
  assert.equal(db.queries.length, 0);
  assert.equal(messaging.calls.length, 0);
});

test('sends to every device of the people named, and only theirs', async () => {
  const db = fakeDb([
    { token: 'phone-ruth', uid: 'ruth' },
    { token: 'laptop-ruth', uid: 'ruth' },
    { token: 'phone-joe', uid: 'joe' },
    { token: 'phone-other', uid: 'other' },
  ]);
  const messaging = fakeMessaging();
  const res = await deliver({ db, messaging }, ['ruth', 'joe'], { title: 'Hello', body: 'World' });
  assert.deepEqual(res, { devices: 3, sent: 3, removed: 0 });
  assert.equal(messaging.calls.length, 1);
  const call = messaging.calls[0];
  assert.deepEqual(call.tokens.sort(), ['laptop-ruth', 'phone-joe', 'phone-ruth']);
  assert.deepEqual(call.notification, { title: 'Hello', body: 'World' });
  assert.equal(call.webpush.fcmOptions.link, 'https://lukulu-bread-of-life.web.app/');
});

test('a person with no registered device is simply skipped', async () => {
  const db = fakeDb([{ token: 'a', uid: 'ruth' }]);
  const messaging = fakeMessaging();
  const res = await deliver({ db, messaging }, ['joe'], { title: 't', body: 'b' });
  assert.deepEqual(res, { devices: 0, sent: 0, removed: 0 });
  assert.equal(messaging.calls.length, 0);
});

test('devices that no longer exist are removed; other failures are kept', async () => {
  const db = fakeDb([
    { token: 'good', uid: 'u' },
    { token: 'gone', uid: 'u' },
    { token: 'bad-format', uid: 'u' },
    { token: 'flaky', uid: 'u' },
  ]);
  const messaging = fakeMessaging({
    gone: 'messaging/registration-token-not-registered',
    'bad-format': 'messaging/invalid-registration-token',
    flaky: 'messaging/internal-error',
  });
  const res = await deliver({ db, messaging }, ['u'], { title: 't', body: 'b' });
  assert.deepEqual(res, { devices: 4, sent: 1, removed: 2 });
  assert.deepEqual(db.deleted.sort(), ['bad-format', 'gone']);
});

test('many people are looked up 30 at a time, and many devices sent 500 at a time', async () => {
  const uids = Array.from({ length: 65 }, (_, i) => `u${i}`);
  const rows = [];
  for (const uid of uids) for (let d = 0; d < 9; d++) rows.push({ token: `${uid}-d${d}`, uid });
  const db = fakeDb(rows); // 585 devices
  const messaging = fakeMessaging();
  const res = await deliver({ db, messaging }, uids, { title: 't', body: 'b' });
  assert.equal(res.devices, 585);
  assert.equal(res.sent, 585);
  assert.deepEqual(db.queries.map((q) => q.length), [30, 30, 5]);
  assert.deepEqual(messaging.calls.map((c) => c.tokens.length), [500, 85]);
});

test('the same person named twice is looked up once', async () => {
  const db = fakeDb([{ token: 'a', uid: 'u' }]);
  const tokens = await tokensFor(db, ['u', 'u', 'u']);
  assert.equal(tokens.length, 1);
  assert.deepEqual(db.queries, [['u']]);
});
