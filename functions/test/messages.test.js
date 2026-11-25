'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const m = require('../lib/messages');

test('snippet keeps short text and shortens long text on one line', () => {
  assert.equal(m.snippet('Hello  world\n again'), 'Hello world again');
  assert.equal(m.snippet('x'.repeat(10), 10), 'xxxxxxxxxx');
  const cut = m.snippet('word '.repeat(60), 30);
  assert.ok(cut.length <= 30, cut);
  assert.ok(cut.endsWith('…'));
  assert.equal(m.snippet(null), '');
  assert.equal(m.snippet(undefined), '');
});

test('dateText writes a date in Zambian time from a Date, a Timestamp or text', () => {
  assert.equal(m.dateText(new Date('2026-11-22T10:00:00Z')), '22 Nov 2026');
  assert.equal(m.dateText({ toDate: () => new Date('2026-12-02T09:00:00Z') }), '2 Dec 2026');
  assert.equal(m.dateText('2026-11-22T10:00:00Z'), '22 Nov 2026');
  // 23:30 UTC is already the next day in Lusaka (UTC+2)
  assert.equal(m.dateText(new Date('2026-11-22T23:30:00Z')), '23 Nov 2026');
  assert.equal(m.dateText('not a date'), '');
});

test('a new report says which ministry, who wrote it and what it is about', () => {
  const n = m.newReport({
    ministry: 'Choir', authorName: 'Ruth Banda', position: 'Leader',
    summary: 'Rehearsed for the Christmas cantata.',
  });
  assert.equal(n.title, 'New report: Choir');
  assert.equal(n.body, 'Ruth Banda, Leader: Rehearsed for the Christmas cantata.');
});

test('a long report is cut short for the lock screen', () => {
  const n = m.newReport({ ministry: 'Choir', authorName: 'R', position: 'L', summary: 'a '.repeat(500) });
  assert.ok(n.body.length <= 120);
});

test('a reviewed report carries the reply, or a plain line when there is none', () => {
  assert.deepEqual(m.reportReviewed({ ministry: 'Choir', pastorNote: 'Well done.' }), {
    title: 'Your Choir report was reviewed',
    body: 'Well done.',
  });
  assert.equal(m.reportReviewed({ ministry: 'Choir', pastorNote: '' }).body, 'The Pastor has read your report.');
});

test('an approval request names the role or the position asked for', () => {
  assert.deepEqual(m.approvalNeeded('Joseph Phiri', { requestedRole: 'finance' }), {
    title: 'Approval needed',
    body: 'Joseph Phiri asked to be Finance Officer.',
  });
  assert.equal(
    m.approvalNeeded('Ruth', { requestedPosition: { ministry: 'Choir', title: 'Leader' } }).body,
    'Ruth asked to be Choir · Leader.',
  );
  assert.equal(m.approvalNeeded('', { requestedRole: 'pastor' }).body, 'Someone asked to be Pastor.');
});

test('a saved income form says when and by whom, and never an amount', () => {
  const n = m.incomeFormSaved({
    date: new Date('2026-11-22T08:00:00Z'), service: 'morning',
    enteredBy: 'Mary Banda', grandTotal: 2279, tithe: 800,
  });
  assert.equal(n.title, 'Sunday income form saved');
  assert.equal(n.body, '22 Nov 2026 · Morning service, entered by Mary Banda');
  assert.ok(!/\d{3,}/.test(n.body.replace('2026', '')), 'no amount in the text');
  assert.ok(!/ZMW|K\d/.test(n.title + n.body));
});

test('an evening form says Evening, and falls back to the prepared-by name', () => {
  const n = m.incomeFormSaved({ date: new Date('2026-11-22T17:00:00Z'), service: 'evening', preparedBy: 'Peter' });
  assert.equal(n.body, '22 Nov 2026 · Evening service, entered by Peter');
  assert.equal(m.incomeFormSaved({ date: new Date('2026-11-22T17:00:00Z'), service: 'morning' }).body,
    '22 Nov 2026 · Morning service');
});

test('an announcement uses its title and the start of its text', () => {
  assert.deepEqual(m.announcement({ title: 'Choir practice', content: 'Saturday at 3pm in the hall.' }), {
    title: 'Choir practice',
    body: 'Saturday at 3pm in the hall.',
  });
  assert.equal(m.announcement({ title: '', content: 'x' }).title, 'New announcement');
});

test('a new event says what, when and where', () => {
  assert.deepEqual(
    m.newEvent({ title: 'Christmas service', date: new Date('2026-12-25T07:00:00Z'), location: 'Main hall' }),
    { title: 'New event: Christmas service', body: '25 Dec 2026 · Main hall' },
  );
  assert.equal(m.newEvent({ title: 'Picnic', date: new Date('2026-12-26T07:00:00Z'), location: '' }).body, '26 Dec 2026');
});
