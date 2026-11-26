'use strict';

// Phone notifications for the Lukulu Bread of Life Church app.
//
// Each trigger works out who should hear about a change, then sends one
// notification to every phone or browser they have turned alerts on for.
// The wording is in lib/messages.js and the choice of people in lib/recipients.js
// (both tested without Firebase).

const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } =
  require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions');

const { selectRecipients, newRequests, LEADER_ROLES } = require('./lib/recipients');
const { deliver } = require('./lib/send');
const msg = require('./lib/messages');

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

async function allUsers() {
  const snap = await db.collection('users').get();
  return snap.docs.map((d) => ({ uid: d.id, ...d.data() }));
}

async function notify(who, message, label) {
  try {
    const uids = selectRecipients(await allUsers(), who);
    const result = await deliver({ db, messaging }, uids, message);
    logger.info(`${label}: ${uids.length} people, ${result.devices} devices, ${result.sent} sent, ${result.removed} removed`);
  } catch (e) {
    // A notification failing must never break the change that caused it.
    logger.error(`${label} failed`, e);
  }
}

// A leader sent a ministry report: tell the Pastor and Admin.
exports.onMinistryReportCreated = onDocumentCreated('ministry_reports/{id}', async (event) => {
  const r = event.data && event.data.data();
  if (!r) return;
  await notify({ roles: ['pastor', 'admin'], exclude: [r.authorUid] }, msg.newReport(r), 'new report');
});

// The Pastor reviewed a report: tell its author.
exports.onMinistryReportReviewed = onDocumentUpdated('ministry_reports/{id}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;
  if (before.status === 'reviewed' || after.status !== 'reviewed') return;
  await notify({ uids: [after.authorUid] }, msg.reportReviewed(after), 'report reviewed');
});

// Someone asked for roles or a ministry position: tell the Admin.
exports.onApprovalRequested = onDocumentWritten('users/{uid}', async (event) => {
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after) return;
  const before = event.data.before.exists ? event.data.before.data() : {};
  const asked = newRequests(before, after);
  if (asked.roles.length === 0 && !asked.position) return;
  await notify(
    { roles: ['admin'], exclude: [event.params.uid] },
    msg.approvalNeeded(after.name, asked),
    'approval needed',
  );
});

// A Sunday income form was saved: tell those who may see finances (not the person
// who entered it). The message never carries an amount.
exports.onIncomeFormCreated = onDocumentCreated('income_forms/{id}', async (event) => {
  const f = event.data && event.data.data();
  if (!f) return;
  await notify(
    { roles: ['finance', 'oversight', 'pastor', 'admin'], exclude: [f.enteredByUid] },
    msg.incomeFormSaved(f),
    'income form',
  );
});

// An announcement was posted: everyone, or only leaders for a leaders-only one.
exports.onAnnouncementCreated = onDocumentCreated('announcements/{id}', async (event) => {
  const a = event.data && event.data.data();
  if (!a) return;
  const who = a.targetAudience === 'leaders' ? { roles: LEADER_ROLES } : { everyone: true };
  await notify(who, msg.announcement(a), 'announcement');
});

// An event was added: everyone.
exports.onEventCreated = onDocumentCreated('events/{id}', async (event) => {
  const e = event.data && event.data.data();
  if (!e) return;
  await notify({ everyone: true }, msg.newEvent(e), 'event');
});
