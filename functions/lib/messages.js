'use strict';

// The words of each notification. Pure functions.
//
// Notifications can show on a locked screen, so anything to do with money says
// who and when but never an amount.

const ROLE_LABELS = {
  member: 'Member', deacon: 'Deacon', deaconess: 'Deaconess', elder: 'Elder',
  pastor: 'Pastor', finance: 'Finance Officer', secretariat: 'Secretariat',
  admin: 'Admin', hospitality: 'Hospitality', oversight: 'Financial Oversight',
};

const TIME_ZONE = 'Africa/Lusaka';

/** A short single-line version of [text], at most [max] characters. */
function snippet(text, max = 100) {
  const t = String(text == null ? '' : text).replace(/\s+/g, ' ').trim();
  if (t.length <= max) return t;
  return t.slice(0, Math.max(0, max - 1)).trimEnd() + '…';
}

/** `22 Nov 2026` for a Date, Firestore Timestamp (has toDate) or ISO string. */
function dateText(value) {
  let d = value;
  if (d && typeof d.toDate === 'function') d = d.toDate();
  if (!(d instanceof Date)) d = new Date(d);
  if (Number.isNaN(d.getTime())) return '';
  return new Intl.DateTimeFormat('en-GB', {
    day: 'numeric', month: 'short', year: 'numeric', timeZone: TIME_ZONE,
  }).format(d);
}

function newReport(report) {
  const who = [report.authorName, report.position].filter(Boolean).join(', ');
  return {
    title: `New report: ${snippet(report.ministry, 40) || 'ministry'}`,
    body: snippet(`${who}${who ? ': ' : ''}${report.summary || ''}`, 120),
  };
}

function reportReviewed(report) {
  const note = snippet(report.pastorNote, 120);
  return {
    title: `Your ${snippet(report.ministry, 40) || 'ministry'} report was reviewed`,
    body: note || 'The Pastor has read your report.',
  };
}

/** `a`, `a and b`, or `a, b and c`. */
function inWords(items) {
  if (items.length < 2) return items.join('');
  return `${items.slice(0, -1).join(', ')} and ${items[items.length - 1]}`;
}

/** Someone asked for church roles and/or a ministry position. */
function approvalNeeded(name, { roles = [], position = null }) {
  const who = snippet(name, 40) || 'Someone';
  const asked = roles.map((r) => ROLE_LABELS[r] || r);
  if (position) {
    asked.push(`${snippet(position.ministry, 40)} · ${snippet(position.title, 40)}`);
  }
  return {
    title: 'Approval needed',
    body: snippet(`${who} asked to be ${inWords(asked)}.`, 160),
  };
}

function incomeFormSaved(form) {
  const service = form.service === 'evening' ? 'Evening' : 'Morning';
  const by = form.enteredBy || form.preparedBy || '';
  return {
    title: 'Sunday income form saved',
    body: `${dateText(form.date)} · ${service} service${by ? `, entered by ${snippet(by, 40)}` : ''}`,
  };
}

function announcement(a) {
  return {
    title: snippet(a.title, 60) || 'New announcement',
    body: snippet(a.content, 120),
  };
}

function newEvent(e) {
  const when = dateText(e.date);
  const where = snippet(e.location, 40);
  return {
    title: `New event: ${snippet(e.title, 50)}`,
    body: [when, where].filter(Boolean).join(' · '),
  };
}

module.exports = {
  snippet, dateText, newReport, reportReviewed, approvalNeeded, incomeFormSaved,
  announcement, newEvent, ROLE_LABELS,
};
