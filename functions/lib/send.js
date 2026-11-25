'use strict';

const SITE = 'https://lukulu-bread-of-life.web.app/';
const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

function chunks(list, size) {
  const out = [];
  for (let i = 0; i < list.length; i += size) out.push(list.slice(i, i + size));
  return out;
}

/** The registered phone/browser tokens of these people, from `push_tokens`. */
async function tokensFor(db, uids) {
  const found = [];
  for (const group of chunks([...new Set(uids)], 30)) {
    const snap = await db.collection('push_tokens').where('uid', 'in', group).get();
    snap.forEach((d) => found.push({ token: d.id, ref: d.ref }));
  }
  return found;
}

/**
 * Sends one notification to every device of [uids]. Devices that no longer exist
 * are removed from `push_tokens`.
 *
 * @param {{db: object, messaging: object}} deps  Firestore and Messaging (Admin SDK)
 * @param {string[]} uids
 * @param {{title: string, body: string}} message
 * @param {string} [link]
 */
async function deliver({ db, messaging }, uids, message, link = SITE) {
  if (!uids || uids.length === 0) return { devices: 0, sent: 0, removed: 0 };
  const devices = await tokensFor(db, uids);
  let sent = 0;
  let removed = 0;
  for (const group of chunks(devices, 500)) {
    const res = await messaging.sendEachForMulticast({
      tokens: group.map((d) => d.token),
      notification: { title: message.title, body: message.body },
      webpush: {
        notification: { icon: '/icons/Icon-192.png' },
        fcmOptions: { link },
      },
    });
    sent += res.successCount;
    const dead = [];
    res.responses.forEach((r, i) => {
      if (!r.success && r.error && DEAD_TOKEN_CODES.has(r.error.code)) dead.push(group[i].ref);
    });
    await Promise.all(dead.map((ref) => ref.delete()));
    removed += dead.length;
  }
  return { devices: devices.length, sent, removed };
}

module.exports = { deliver, tokensFor, chunks, SITE };
