import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc,
  collection, getDocs, addDoc, query, where, writeBatch, deleteField,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-church-access';

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
      rules: readFileSync('../firestore.rules', 'utf8'),
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
  await seedDoc('prayer_requests/p1', { userId: 'member1', request: 'pray for me' });

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
  await check('elder CAN read any prayer request', () =>
    assertSucceeds(getDoc(doc(ctxFor('elder1'), 'prayer_requests/p1'))));

  console.log('\n--- Signup role-escalation lockdown ---');
  await check('new user CAN self-signup as member', () =>
    assertSucceeds(setDoc(doc(ctxFor('newbie1'), 'users/newbie1'), { role: 'member', email: 'newbie1@test.com' })));
  await check('new user CANNOT self-signup as admin', () =>
    assertFails(setDoc(doc(ctxFor('newbie2'), 'users/newbie2'), { role: 'admin', email: 'newbie2@test.com' })));
  await check('new user CANNOT self-signup as finance', () =>
    assertFails(setDoc(doc(ctxFor('newbie3'), 'users/newbie3'), { role: 'finance', email: 'newbie3@test.com' })));
  await check('existing member CANNOT self-promote to admin', () =>
    assertFails(updateDoc(doc(ctxFor('member1'), 'users/member1'), { role: 'admin' })));
  await check('admin CAN promote a member to elder', () =>
    assertSucceeds(updateDoc(doc(ctxFor('admin1'), 'users/member1'), { role: 'elder' })));

  await testEnv.cleanup();

  console.log(`\n${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch((e) => {
  console.error('Test run crashed:', e);
  process.exit(1);
});
