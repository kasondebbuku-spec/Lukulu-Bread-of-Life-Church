import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc,
  collection, getDocs, addDoc, query, where, writeBatch, deleteField, serverTimestamp,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-church-access';

// Production has prayer-request sharing switched off (only the Pastor reads them).
// `PRAYER_SHARING=open npm test` flips that switch in a copy of the rules so the
// sharing logic, which is built but dormant, stays tested.
const OPEN = process.env.PRAYER_SHARING === 'open';
function rulesText() {
  let text = readFileSync('../firestore.rules', 'utf8');
  if (OPEN) {
    const off = 'function prayerSharingOpen() { return false; }';
    if (!text.includes(off)) throw new Error('prayerSharingOpen switch not found in firestore.rules');
    text = text.replace(off, 'function prayerSharingOpen() { return true; }');
  }
  return text;
}

let testEnv;
let passed = 0;
let failed = 0;

async function check(label, fn) {
  try {
    await fn();
    console.log(`  ✅ ${label}`);
    passed++;
  } catch (e) {
    console.log(`  ❌ ${label}`);
    console.log(`     ${e.message.split('\n')[0]}`);
    failed++;
  }
}

async function seedUser(uid, role) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', uid), { role, email: `${uid}@test.com` });
  });
}

async function seedDoc(path, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data);
  });
}

function ctxFor(uid) {
  return testEnv.authenticatedContext(uid, { email: `${uid}@test.com` }).firestore();
}

async function main() {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: rulesText(),
      host: 'localhost',
      port: 8080,
    },
  });

  await seedUser('member1', 'member');
  await seedUser('elder1', 'elder');
  await seedUser('finance1', 'finance');
  await seedUser('secretariat1', 'secretariat');
  await seedUser('admin1', 'admin');
  await seedUser('hospitality1', 'hospitality');
  await seedUser('oversight1', 'oversight');
  await seedUser('pastor1', 'pastor');
  await seedDoc('users/combined1', { role: 'member', roles: ['elder', 'finance'] });
  await seedDoc('users/revoked1', { role: 'admin', roles: ['member'] });
  await seedDoc('giving/own1', { memberUserId: 'member1', memberName: 'Test', amount: 100 });
  await seedDoc('giving/other1', { memberUserId: 'finance1', memberName: 'Test', amount: 100 });
  await seedDoc('income_forms/f1', { service: 'sunday' });

  console.log('\n--- Personal giving and combined roles ---');
  await check('member CAN query only own linked contributions', () =>
    assertSucceeds(getDocs(query(collection(ctxFor('member1'), 'giving'), where('memberUserId', '==', 'member1')))));
  await check('member CANNOT read another contribution with the same name', () =>
    assertFails(getDoc(doc(ctxFor('member1'), 'giving/other1'))));
  await check('member CANNOT edit own contribution', () =>
    assertFails(updateDoc(doc(ctxFor('member1'), 'giving/own1'), { amount: 900 })));
  await check('member CANNOT claim another contribution', () =>
    assertFails(updateDoc(doc(ctxFor('member1'), 'giving/other1'), { memberUserId: 'member1' })));
  await check('anonymous CANNOT read linked contribution', () =>
    assertFails(getDoc(doc(testEnv.unauthenticatedContext().firestore(), 'giving/own1'))));
  await check('oversight CAN read financial records', () =>
    assertSucceeds(getDocs(collection(ctxFor('oversight1'), 'giving'))));
  await check('oversight CAN read income forms', () =>
    assertSucceeds(getDoc(doc(ctxFor('oversight1'), 'income_forms/f1'))));
  await check('oversight CANNOT update giving', () =>
    assertFails(updateDoc(doc(ctxFor('oversight1'), 'giving/own1'), { amount: 900 })));
  await check('oversight CANNOT create income forms', () =>
    assertFails(setDoc(doc(ctxFor('oversight1'), 'income_forms/new'), { amount: 100 })));

  console.log('\n--- Pastor: read-only finances, directory and events ---');
  await check('pastor CAN read financial records', () =>
    assertSucceeds(getDocs(collection(ctxFor('pastor1'), 'giving'))));
  await check('pastor CAN read income forms', () =>
    assertSucceeds(getDoc(doc(ctxFor('pastor1'), 'income_forms/f1'))));
  await check('pastor CANNOT update giving', () =>
    assertFails(updateDoc(doc(ctxFor('pastor1'), 'giving/own1'), { amount: 900 })));
  await check('pastor CANNOT create income forms', () =>
    assertFails(setDoc(doc(ctxFor('pastor1'), 'income_forms/newp'), { amount: 100 })));
  await check('pastor CANNOT delete giving', () =>
    assertFails(deleteDoc(doc(ctxFor('pastor1'), 'giving/own1'))));
  await check('pastor CAN register a directory member', () =>
    assertSucceeds(setDoc(doc(ctxFor('pastor1'), 'members/by-pastor'), { name: 'Visitor' })));
  await check('pastor CAN create an event', () =>
    assertSucceeds(setDoc(doc(ctxFor('pastor1'), 'events/by-pastor'), { title: 'Service' })));
  await check('pastor CANNOT change other accounts\' roles', () =>
    assertFails(updateDoc(doc(ctxFor('pastor1'), 'users/member1'), { roles: ['admin'] })));
  await check('elder CANNOT create an event', () =>
    assertFails(setDoc(doc(ctxFor('elder1'), 'events/by-elder'), { title: 'Service' })));
  await check('elder CANNOT register a directory member', () =>
    assertFails(setDoc(doc(ctxFor('elder1'), 'members/by-elder'), { name: 'Visitor' })));
  await check('hospitality CAN register a directory member', () =>
    assertSucceeds(setDoc(doc(ctxFor('hospitality1'), 'members/visitor'), { name: 'Visitor' })));
  await check('hospitality CANNOT read giving', () =>
    assertFails(getDocs(collection(ctxFor('hospitality1'), 'giving'))));
  await check('combined finance leader CAN read giving', () =>
    assertSucceeds(getDocs(collection(ctxFor('combined1'), 'giving'))));
  await check('combined finance leader CAN record attendance', () =>
    assertSucceeds(setDoc(doc(ctxFor('combined1'), 'attendance/combined'), { count: 10 })));
  await check('roles array revokes legacy admin', () =>
    assertFails(getDocs(collection(ctxFor('revoked1'), 'giving'))));
  await check('member CANNOT add roles array', () =>
    assertFails(updateDoc(doc(ctxFor('member1'), 'users/member1'), { roles: ['finance'] })));
  await check('member CANNOT sign up with elevated roles array', () =>
    assertFails(setDoc(doc(ctxFor('escalate1'), 'users/escalate1'), { role: 'member', email: 'escalate1@test.com', roles: ['finance'] })));
  await check('revoked user CANNOT remove roles to restore legacy admin', () =>
    assertFails(updateDoc(doc(ctxFor('revoked1'), 'users/revoked1'), { roles: deleteField() })));
  await check('finance CANNOT assign roles', () =>
    assertFails(updateDoc(doc(ctxFor('finance1'), 'users/member1'), { roles: ['finance'] })));
  await check('admin CAN assign multiple roles', () =>
    assertSucceeds(updateDoc(doc(ctxFor('admin1'), 'users/combined1'), { roles: ['elder', 'finance'] })));
  await check('admin CANNOT remove own admin access', () =>
    assertFails(updateDoc(doc(ctxFor('admin1'), 'users/admin1'), { roles: ['member'] })));
  await check('finance CANNOT link a service total to an individual', () =>
    assertFails(setDoc(doc(ctxFor('finance1'), 'giving/aggregate'), { memberUserId: 'member1', denominationBreakdown: { '100': 2 }, amount: 200 })));
  await check('finance CANNOT link to a nonexistent account', () =>
    assertFails(setDoc(doc(ctxFor('finance1'), 'giving/nonexistent'), { memberUserId: 'missing', amount: 100 })));
  await check('finance CAN save income form and attendance atomically', () => {
    const db = ctxFor('finance1');
    const batch = writeBatch(db);
    batch.set(doc(db, 'income_forms/batch-form'), { service: 'sunday' });
    batch.set(doc(db, 'attendance/batch-attendance'), { incomeFormId: 'batch-form', count: 10 });
    return assertSucceeds(batch.commit());
  });
  await check('finance CANNOT create arbitrary attendance', () =>
    assertFails(setDoc(doc(ctxFor('finance1'), 'attendance/unrelated'), { count: 10 })));
  await check('member CANNOT change profile email to impersonate another account', () =>
    assertFails(updateDoc(doc(ctxFor('member1'), 'users/member1'), { email: 'finance1@test.com' })));

  await seedDoc('giving/g1', { memberName: 'Test', amount: 100, currency: 'ZMW' });
  await seedDoc('members/m1', { name: 'Test Member', email: 'x@x.com', phone: '000' });
  await seedDoc('attendance/a1', { date: new Date().toISOString(), count: 50, newVisitors: 2 });
  await seedDoc('announcements/pub1', { title: 'Public', content: 'hi', targetAudience: 'all' });
  await seedDoc('announcements/priv1', { title: 'Leaders', content: 'secret', targetAudience: 'leaders' });
  await seedDoc('prayer_requests/p1', { userId: 'member1', request: 'pray for me' }); // before the audience choice existed

  console.log('\n--- Giving (financial records) ---');
  await check('member CANNOT read giving', () =>
    assertFails(getDocs(collection(ctxFor('member1'), 'giving'))));
  await check('elder CANNOT read giving', () =>
    assertFails(getDocs(collection(ctxFor('elder1'), 'giving'))));
  await check('secretariat CANNOT read giving', () =>
    assertFails(getDocs(collection(ctxFor('secretariat1'), 'giving'))));
  await check('finance CAN read giving', () =>
    assertSucceeds(getDocs(collection(ctxFor('finance1'), 'giving'))));
  await check('admin CAN read giving', () =>
    assertSucceeds(getDocs(collection(ctxFor('admin1'), 'giving'))));
  await check('finance CAN add a giving record', () =>
    assertSucceeds(addDoc(collection(ctxFor('finance1'), 'giving'), { memberName: 'X', amount: 50 })));
  await check('member CANNOT add a giving record', () =>
    assertFails(addDoc(collection(ctxFor('member1'), 'giving'), { memberName: 'X', amount: 50 })));

  console.log('\n--- Members directory (PII) ---');
  await check('member CANNOT read members directory', () =>
    assertFails(getDocs(collection(ctxFor('member1'), 'members'))));
  await check('secretariat CAN read members directory', () =>
    assertSucceeds(getDocs(collection(ctxFor('secretariat1'), 'members'))));

  console.log('\n--- Attendance ---');
  await check('member CANNOT read attendance', () =>
    assertFails(getDocs(collection(ctxFor('member1'), 'attendance'))));
  await check('elder CAN read attendance', () =>
    assertSucceeds(getDocs(collection(ctxFor('elder1'), 'attendance'))));

  console.log('\n--- Announcements (leaders-only enforcement) ---');
  await check('member CAN read public announcement', () =>
    assertSucceeds(getDoc(doc(ctxFor('member1'), 'announcements/pub1'))));
  await check('member CANNOT read leaders-only announcement', () =>
    assertFails(getDoc(doc(ctxFor('member1'), 'announcements/priv1'))));
  await check('elder CAN read leaders-only announcement', () =>
    assertSucceeds(getDoc(doc(ctxFor('elder1'), 'announcements/priv1'))));

  console.log('\n--- Prayer requests ---');
  await check('member CAN read own prayer request', () =>
    assertSucceeds(getDoc(doc(ctxFor('member1'), 'prayer_requests/p1'))));
  await check('other member CANNOT read someone else\'s prayer request', async () => {
    await seedUser('member2', 'member');
    return assertFails(getDoc(doc(ctxFor('member2'), 'prayer_requests/p1')));
  });
  if (OPEN) {
    await check('elder CAN read any prayer request', () =>
      assertSucceeds(getDoc(doc(ctxFor('elder1'), 'prayer_requests/p1'))));
  } else {
    await check('elder CANNOT read someone else\'s prayer request (only the Pastor can)', () =>
      assertFails(getDoc(doc(ctxFor('elder1'), 'prayer_requests/p1'))));
    await check('pastor CAN read any prayer request', () =>
      assertSucceeds(getDoc(doc(ctxFor('pastor1'), 'prayer_requests/p1'))));
  }

  console.log('\n--- Prayer requests: the author chooses who sees them ---');
  await seedUser('deacon1', 'deacon');
  await seedUser('deaconess1', 'deaconess');
  await seedDoc('users/eldpastor1', { role: 'member', roles: ['elder', 'pastor'] });
  const pr = (audience) => ({ userId: 'member1', userName: 'M', request: 'pray', status: 'pending', ...(audience ? { audience } : {}) });
  await seedDoc('prayer_requests/aud_pastor', pr('pastor'));
  await seedDoc('prayer_requests/aud_elders', pr('pastor_elders'));
  await seedDoc('prayer_requests/aud_leaders', pr('leaders'));
  await seedDoc('prayer_requests/aud_change', pr('pastor'));
  await seedDoc('prayer_requests/legacy_ok', pr(null)); // as the app wrote it before the choice: has a status, no audience
  const readable = (uid, id) => getDoc(doc(ctxFor(uid), 'prayer_requests/' + id));
  const asks = (uid, audiences) => getDocs(query(collection(ctxFor(uid), 'prayer_requests'), where('audience', 'in', audiences)));
  const ALL = ['pastor', 'pastor_elders', 'leaders'];

  if (OPEN) {
  await check('author CAN read their own, whichever audience', async () => {
    for (const id of ['aud_pastor', 'aud_elders', 'aud_leaders']) await assertSucceeds(readable('member1', id));
  });
  await check('pastor CAN read all three audiences', async () => {
    for (const id of ['aud_pastor', 'aud_elders', 'aud_leaders']) await assertSucceeds(readable('pastor1', id));
  });
  await check('pastor CAN list every audience', () => assertSucceeds(asks('pastor1', ALL)));
  await check('elder CANNOT read a Pastor-only request', () => assertFails(readable('elder1', 'aud_pastor')));
  await check('elder CAN read Pastor-and-Elders and All-leaders', async () => {
    await assertSucceeds(readable('elder1', 'aud_elders'));
    await assertSucceeds(readable('elder1', 'aud_leaders'));
  });
  await check('elder CAN list the two audiences they may read', () => assertSucceeds(asks('elder1', ['pastor_elders', 'leaders'])));
  await check('elder CANNOT list the Pastor-only audience', () => assertFails(asks('elder1', ALL)));
  for (const who of ['deacon1', 'deaconess1', 'secretariat1', 'admin1']) {
    await check(who + ' CANNOT read Pastor-only or Pastor-and-Elders', async () => {
      await assertFails(readable(who, 'aud_pastor'));
      await assertFails(readable(who, 'aud_elders'));
    });
    await check(who + ' CAN read an All-leaders request and list that audience', async () => {
      await assertSucceeds(readable(who, 'aud_leaders'));
      await assertSucceeds(asks(who, ['leaders']));
    });
  }
  await check('another member CANNOT read any of them', async () => {
    for (const id of ['aud_pastor', 'aud_elders', 'aud_leaders']) await assertFails(readable('member2', id));
  });
  await check('finance and oversight CANNOT read prayer requests', async () => {
    await assertFails(readable('finance1', 'aud_leaders'));
    await assertFails(readable('oversight1', 'aud_leaders'));
  });
  await check('a leader with two roles gets the wider access', async () => {
    await assertSucceeds(readable('eldpastor1', 'aud_pastor'));
  });
  await check('a request from before the choice reads as All-leaders', async () => {
    await assertSucceeds(readable('elder1', 'p1'));
    await assertSucceeds(readable('deacon1', 'p1'));
    await assertSucceeds(readable('pastor1', 'p1'));
  });

  await check('a new request CAN be created with each valid audience', async () => {
    for (const a of ALL) await assertSucceeds(addDoc(collection(ctxFor('member1'), 'prayer_requests'), pr(a)));
  });
  await check('a new request CANNOT be created without an audience', () =>
    assertFails(addDoc(collection(ctxFor('member1'), 'prayer_requests'), pr(null))));
  await check('a new request CANNOT use an unknown audience', () =>
    assertFails(addDoc(collection(ctxFor('member1'), 'prayer_requests'), pr('everyone'))));
  await check('a new request CANNOT be created in someone else\'s name', () =>
    assertFails(addDoc(collection(ctxFor('member2'), 'prayer_requests'), pr('pastor'))));

  await check('author CAN change who sees their request', () =>
    assertSucceeds(updateDoc(doc(ctxFor('member1'), 'prayer_requests/aud_change'), { audience: 'leaders' })));
  await check('author CANNOT set an unknown audience', () =>
    assertFails(updateDoc(doc(ctxFor('member1'), 'prayer_requests/aud_elders'), { audience: 'everyone' })));
  await check('author CAN reword a request from before the choice, without touching its audience', () =>
    assertSucceeds(updateDoc(doc(ctxFor('member1'), 'prayer_requests/legacy_ok'), { request: 'pray for me, updated' })));
  await check('pastor CAN mark a request answered', () =>
    assertSucceeds(updateDoc(doc(ctxFor('pastor1'), 'prayer_requests/aud_elders'), { status: 'answered' })));
  await check('a leader CANNOT widen who sees someone else\'s request', () =>
    assertFails(updateDoc(doc(ctxFor('pastor1'), 'prayer_requests/aud_elders'), { audience: 'leaders' })));
  await check('a leader CANNOT reword someone else\'s request', () =>
    assertFails(updateDoc(doc(ctxFor('elder1'), 'prayer_requests/aud_elders'), { request: 'defaced' })));
  await check('elder CANNOT mark or delete a Pastor-only request', async () => {
    await assertFails(updateDoc(doc(ctxFor('elder1'), 'prayer_requests/aud_pastor'), { status: 'answered' }));
    await assertFails(deleteDoc(doc(ctxFor('elder1'), 'prayer_requests/aud_pastor')));
  });
  await check('a leader CANNOT delete a request shared only with a smaller group', () =>
    assertFails(deleteDoc(doc(ctxFor('deacon1'), 'prayer_requests/aud_elders'))));
  await check('pastor CAN delete a request shared with them', () =>
    assertSucceeds(deleteDoc(doc(ctxFor('pastor1'), 'prayer_requests/aud_elders'))));
  } else {
    // Sharing is switched off: only the Pastor (and the author) read a request,
    // whatever audience it carries.
    for (const id of ['aud_pastor', 'aud_elders', 'aud_leaders', 'p1']) {
      await check('pastor CAN read ' + id, () => assertSucceeds(readable('pastor1', id)));
    }
    await check('pastor CAN list every audience', () => assertSucceeds(asks('pastor1', ALL)));
    await check('author CAN still read their own, whatever it carries', async () => {
      for (const id of ['aud_pastor', 'aud_elders', 'aud_leaders']) await assertSucceeds(readable('member1', id));
    });
    for (const who of ['elder1', 'deacon1', 'deaconess1', 'secretariat1', 'admin1', 'finance1', 'oversight1', 'member2']) {
      await check(who + ' CANNOT read any request, even one marked All leaders', async () => {
        for (const id of ['aud_pastor', 'aud_elders', 'aud_leaders', 'p1']) await assertFails(readable(who, id));
      });
    }
    await check('elder CANNOT list any audience', () => assertFails(asks('elder1', ['leaders'])));
    await check('admin CANNOT list any audience', () => assertFails(asks('admin1', ['leaders'])));
    await check('a leader CAN read their own request', async () => {
      await seedDoc('prayer_requests/deacon_own', { userId: 'deacon1', userName: 'D', request: 'pray', status: 'pending', audience: 'pastor' });
      await assertSucceeds(readable('deacon1', 'deacon_own'));
    });

    await check('a new request CAN be created for the Pastor only', () =>
      assertSucceeds(addDoc(collection(ctxFor('member1'), 'prayer_requests'), pr('pastor'))));
    for (const a of ['pastor_elders', 'leaders', 'everyone']) {
      await check('a new request CANNOT be created as ' + a, () =>
        assertFails(addDoc(collection(ctxFor('member1'), 'prayer_requests'), pr(a))));
    }
    await check('a new request CANNOT be created without an audience', () =>
      assertFails(addDoc(collection(ctxFor('member1'), 'prayer_requests'), pr(null))));

    await check('author CAN reword a request that still carries an old audience', () =>
      assertSucceeds(updateDoc(doc(ctxFor('member1'), 'prayer_requests/aud_leaders'), { request: 'reworded' })));
    await check('author CAN reword a request from before the choice', () =>
      assertSucceeds(updateDoc(doc(ctxFor('member1'), 'prayer_requests/legacy_ok'), { request: 'reworded' })));
    await check('author CAN make an old request Pastor-only', () =>
      assertSucceeds(updateDoc(doc(ctxFor('member1'), 'prayer_requests/aud_elders'), { audience: 'pastor' })));
    await check('author CANNOT widen a request to leaders', () =>
      assertFails(updateDoc(doc(ctxFor('member1'), 'prayer_requests/aud_change'), { audience: 'leaders' })));
    await check('author CANNOT widen a request to Pastor and Elders', () =>
      assertFails(updateDoc(doc(ctxFor('member1'), 'prayer_requests/aud_change'), { audience: 'pastor_elders' })));

    await check('pastor CAN mark a request answered', () =>
      assertSucceeds(updateDoc(doc(ctxFor('pastor1'), 'prayer_requests/aud_pastor'), { status: 'answered' })));
    await check('pastor CANNOT reword or widen someone else\'s request', async () => {
      await assertFails(updateDoc(doc(ctxFor('pastor1'), 'prayer_requests/aud_change'), { request: 'defaced' }));
      await assertFails(updateDoc(doc(ctxFor('pastor1'), 'prayer_requests/aud_change'), { audience: 'leaders' }));
    });
    await check('elder CANNOT mark or delete a request', async () => {
      await assertFails(updateDoc(doc(ctxFor('elder1'), 'prayer_requests/aud_pastor'), { status: 'answered' }));
      await assertFails(deleteDoc(doc(ctxFor('elder1'), 'prayer_requests/aud_pastor')));
    });
    await check('admin CANNOT mark or delete a request', async () => {
      await assertFails(updateDoc(doc(ctxFor('admin1'), 'prayer_requests/aud_leaders'), { status: 'answered' }));
      await assertFails(deleteDoc(doc(ctxFor('admin1'), 'prayer_requests/aud_leaders')));
    });
    await check('pastor CAN delete a request', () =>
      assertSucceeds(deleteDoc(doc(ctxFor('pastor1'), 'prayer_requests/aud_elders'))));
  }

  console.log('\n--- Signup role-escalation lockdown ---');
  await check('new user CAN self-signup as member', () =>
    assertSucceeds(setDoc(doc(ctxFor('newbie1'), 'users/newbie1'), { role: 'member', email: 'newbie1@test.com' })));
  await check('new user CANNOT self-signup as admin', () =>
    assertFails(setDoc(doc(ctxFor('newbie2'), 'users/newbie2'), { role: 'admin', email: 'newbie2@test.com' })));
  await check('new user CANNOT self-signup as finance', () =>
    assertFails(setDoc(doc(ctxFor('newbie3'), 'users/newbie3'), { role: 'finance', email: 'newbie3@test.com' })));
  console.log('\n--- Role requests at sign-up (Admin approves) ---');
  await check('sign-up CAN ask for finance but is still only a member', async () => {
    await assertSucceeds(setDoc(doc(ctxFor('asker1'), 'users/asker1'),
      { role: 'member', email: 'asker1@test.com', requestedRole: 'finance' }));
    // asking grants nothing: the finance records stay closed
    await assertFails(getDocs(collection(ctxFor('asker1'), 'giving')));
  });
  await check('sign-up CANNOT ask for admin', () =>
    assertFails(setDoc(doc(ctxFor('asker2'), 'users/asker2'),
      { role: 'member', email: 'asker2@test.com', requestedRole: 'admin' })));
  await check('sign-up CANNOT ask for a made-up role', () =>
    assertFails(setDoc(doc(ctxFor('asker3'), 'users/asker3'),
      { role: 'member', email: 'asker3@test.com', requestedRole: 'superuser' })));
  await check('sign-up CANNOT ask and grant themselves in one go', () =>
    assertFails(setDoc(doc(ctxFor('asker4'), 'users/asker4'),
      { role: 'member', email: 'asker4@test.com', requestedRole: 'finance', roles: ['finance'] })));
  await check('a requester CANNOT approve themselves', () =>
    assertFails(updateDoc(doc(ctxFor('asker1'), 'users/asker1'), { roles: ['finance'] })));
  await check('a requester CANNOT change their request later', () =>
    assertFails(updateDoc(doc(ctxFor('asker1'), 'users/asker1'), { requestedRole: 'pastor' })));
  await check('admin CAN approve a request and clear it', async () => {
    await assertSucceeds(updateDoc(doc(ctxFor('admin1'), 'users/asker1'),
      { roles: ['finance'], requestedRole: deleteField() }));
    await assertSucceeds(getDocs(collection(ctxFor('asker1'), 'giving')));
  });
  await check('finance CANNOT approve requests', () =>
    assertFails(updateDoc(doc(ctxFor('finance1'), 'users/member1'), { roles: ['finance'] })));

  console.log('\n--- Notifications "last seen" marker ---');
  await check('a user CAN stamp their own notificationsSeenAt with server time', () =>
    assertSucceeds(updateDoc(doc(ctxFor('member1'), 'users/member1'),
      { notificationsSeenAt: serverTimestamp() })));
  await check('a user CANNOT set notificationsSeenAt to a made-up time', () =>
    assertFails(updateDoc(doc(ctxFor('member1'), 'users/member1'),
      { notificationsSeenAt: new Date('2020-01-01') })));
  await check('a user CANNOT set notificationsSeenAt to text', () =>
    assertFails(updateDoc(doc(ctxFor('member1'), 'users/member1'),
      { notificationsSeenAt: 'now' })));
  await check('a user CANNOT sneak a role change in with the marker', () =>
    assertFails(updateDoc(doc(ctxFor('member1'), 'users/member1'),
      { notificationsSeenAt: serverTimestamp(), roles: ['admin'] })));
  await check('a user CANNOT stamp someone else\'s marker', () =>
    assertFails(updateDoc(doc(ctxFor('member1'), 'users/elder1'),
      { notificationsSeenAt: serverTimestamp() })));

  await check('existing member CANNOT self-promote to admin', () =>
    assertFails(updateDoc(doc(ctxFor('member1'), 'users/member1'), { role: 'admin' })));
  await check('admin CAN promote a member to elder', () =>
    assertSucceeds(updateDoc(doc(ctxFor('admin1'), 'users/member1'), { role: 'elder' })));

  console.log('\n--- Editing and deleting Sunday Income Forms ---');
  await seedDoc('attendance/linked1', { incomeFormId: 'f1', count: 5 });
  await seedDoc('attendance/linked2', { incomeFormId: 'f1', count: 6 });
  await seedDoc('attendance/unlinked1', { count: 3 });
  await check('finance CAN update attendance created by a form', () =>
    assertSucceeds(updateDoc(doc(ctxFor('finance1'), 'attendance/linked1'), { count: 9 })));
  await check('finance CANNOT update attendance not created by a form', () =>
    assertFails(updateDoc(doc(ctxFor('finance1'), 'attendance/unlinked1'), { count: 9 })));
  await check('finance CANNOT relink a form attendance record', () =>
    assertFails(updateDoc(doc(ctxFor('finance1'), 'attendance/linked2'), { incomeFormId: 'other' })));
  await check('finance CANNOT strip the form link from attendance', () =>
    assertFails(updateDoc(doc(ctxFor('finance1'), 'attendance/linked2'), { incomeFormId: '' })));
  await check('finance CAN delete attendance created by a form', () =>
    assertSucceeds(deleteDoc(doc(ctxFor('finance1'), 'attendance/linked2'))));
  await check('finance CANNOT delete attendance not created by a form', () =>
    assertFails(deleteDoc(doc(ctxFor('finance1'), 'attendance/unlinked1'))));
  await check('member CANNOT update form attendance', () =>
    assertFails(updateDoc(doc(ctxFor('member2'), 'attendance/linked1'), { count: 1 })));
  await check('oversight CANNOT delete form attendance', () =>
    assertFails(deleteDoc(doc(ctxFor('oversight1'), 'attendance/linked1'))));
  await check('finance still CANNOT read attendance', () =>
    assertFails(getDoc(doc(ctxFor('finance1'), 'attendance/linked1'))));
  await seedDoc('income_forms/edit1', { service: 'sunday' });
  await seedDoc('giving/edit1_tithe', { memberName: 'Tithe', amount: 100, incomeFormId: 'edit1' });
  await seedDoc('attendance/edit1_attendance', { incomeFormId: 'edit1', count: 10 });
  await check('finance CAN edit a form and its derived records in one batch', () => {
    const db = ctxFor('finance1');
    const batch = writeBatch(db);
    batch.set(doc(db, 'income_forms/edit1'), { service: 'sunday', updated: true }, { merge: true });
    batch.set(doc(db, 'giving/edit1_tithe'), { memberName: 'Tithe', amount: 250, incomeFormId: 'edit1' });
    batch.delete(doc(db, 'giving/edit1_offering'));
    batch.set(doc(db, 'attendance/edit1_attendance'), { incomeFormId: 'edit1', count: 12 });
    return assertSucceeds(batch.commit());
  });
  await check('finance CAN delete a form and its derived records in one batch', () => {
    const db = ctxFor('finance1');
    const batch = writeBatch(db);
    batch.delete(doc(db, 'giving/edit1_tithe'));
    batch.delete(doc(db, 'attendance/edit1_attendance'));
    batch.delete(doc(db, 'income_forms/edit1'));
    return assertSucceeds(batch.commit());
  });

  console.log('\n--- Activity log (audit_log) ---');
  const entry = (uid, action = 'update') => ({
    action, entity: 'income_form', entityId: 'f1', summary: 'Oct 4, 2026',
    detail: 'Total 1 -> 2', userId: uid, userName: uid,
  });
  await seedDoc('audit_log/existing1', entry('finance1'));
  await check('finance CAN add an entry naming themselves', () =>
    assertSucceeds(setDoc(doc(ctxFor('finance1'), 'audit_log/new1'), entry('finance1'))));
  await check('finance CANNOT add an entry in someone else\'s name', () =>
    assertFails(setDoc(doc(ctxFor('finance1'), 'audit_log/new2'), entry('admin1'))));
  await check('finance CANNOT add an entry with an unknown action', () =>
    assertFails(setDoc(doc(ctxFor('finance1'), 'audit_log/new3'), entry('finance1', 'tamper'))));
  await check('member CANNOT add an entry', () =>
    assertFails(setDoc(doc(ctxFor('member2'), 'audit_log/new4'), entry('member2'))));
  await check('finance CAN read the log', () =>
    assertSucceeds(getDocs(collection(ctxFor('finance1'), 'audit_log'))));
  await check('oversight CAN read the log', () =>
    assertSucceeds(getDocs(collection(ctxFor('oversight1'), 'audit_log'))));
  await check('member CANNOT read the log', () =>
    assertFails(getDocs(collection(ctxFor('member2'), 'audit_log'))));
  await check('finance CANNOT edit an entry', () =>
    assertFails(updateDoc(doc(ctxFor('finance1'), 'audit_log/existing1'), { detail: 'rewritten' })));
  await check('admin CANNOT edit an entry', () =>
    assertFails(updateDoc(doc(ctxFor('admin1'), 'audit_log/existing1'), { detail: 'rewritten' })));
  await check('finance CANNOT delete an entry', () =>
    assertFails(deleteDoc(doc(ctxFor('finance1'), 'audit_log/existing1'))));
  await check('admin CANNOT delete an entry', () =>
    assertFails(deleteDoc(doc(ctxFor('admin1'), 'audit_log/existing1'))));
  await seedDoc('income_forms/aud1', { service: 'sunday' });
  await seedDoc('giving/aud1_tithe', { memberName: 'Tithe', amount: 100, incomeFormId: 'aud1' });
  await seedDoc('attendance/aud1_attendance', { incomeFormId: 'aud1', count: 10 });
  await check('finance CAN delete a form with its log entry in one batch', () => {
    const db = ctxFor('finance1');
    const batch = writeBatch(db);
    batch.delete(doc(db, 'giving/aud1_tithe'));
    batch.delete(doc(db, 'attendance/aud1_attendance'));
    batch.delete(doc(db, 'income_forms/aud1'));
    batch.set(doc(db, 'audit_log/del1'), entry('finance1', 'delete'));
    return assertSucceeds(batch.commit());
  });

  console.log('\n--- Members editing and deleting their own prayer requests ---');
  await seedUser('member3', 'member');
  const prayer = (uid) => ({ userId: uid, userName: uid, request: 'original', status: 'pending' });
  await seedDoc('prayer_requests/own2', prayer('member2'));
  await seedDoc('prayer_requests/own3', prayer('member3'));
  await seedDoc('prayer_requests/own4', prayer('member2'));
  await check('owner CAN edit the wording of their own request', () =>
    assertSucceeds(updateDoc(doc(ctxFor('member2'), 'prayer_requests/own2'), { request: 'reworded' })));
  await check('owner CAN mark their own request answered', () =>
    assertSucceeds(updateDoc(doc(ctxFor('member2'), 'prayer_requests/own2'), { status: 'answered' })));
  await check('owner CANNOT set an invalid status', () =>
    assertFails(updateDoc(doc(ctxFor('member2'), 'prayer_requests/own2'), { status: 'hacked' })));
  await check('owner CANNOT blank the request', () =>
    assertFails(updateDoc(doc(ctxFor('member2'), 'prayer_requests/own2'), { request: '' })));
  await check('owner CANNOT make the request enormous', () =>
    assertFails(updateDoc(doc(ctxFor('member2'), 'prayer_requests/own2'), { request: 'x'.repeat(2001) })));
  await check('owner CANNOT reassign the request to someone else', () =>
    assertFails(updateDoc(doc(ctxFor('member2'), 'prayer_requests/own2'), { userId: 'member3' })));
  await check('owner CANNOT change other fields', () =>
    assertFails(updateDoc(doc(ctxFor('member2'), 'prayer_requests/own2'), { userName: 'someone else' })));
  await check('a member CANNOT edit another member\'s request', () =>
    assertFails(updateDoc(doc(ctxFor('member2'), 'prayer_requests/own3'), { request: 'defaced' })));
  await check('a member CANNOT delete another member\'s request', () =>
    assertFails(deleteDoc(doc(ctxFor('member2'), 'prayer_requests/own3'))));
  await check('owner CAN delete their own request', () =>
    assertSucceeds(deleteDoc(doc(ctxFor('member2'), 'prayer_requests/own4'))));
  await check(OPEN ? 'a leader CAN still delete any request' : 'the pastor CAN delete any request', () =>
    assertSucceeds(deleteDoc(doc(ctxFor(OPEN ? 'elder1' : 'pastor1'), 'prayer_requests/own3'))));
  await check('anonymous CANNOT edit a request', () =>
    assertFails(updateDoc(doc(testEnv.unauthenticatedContext().firestore(), 'prayer_requests/own2'), { request: 'x' })));

  await testEnv.cleanup();

  console.log(`\n${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch((e) => {
  console.error('Test run crashed:', e);
  process.exit(1);
});
