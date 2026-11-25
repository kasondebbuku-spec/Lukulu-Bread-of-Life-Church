'use strict';

// Who should hear about something. Pure functions: no Firebase in here, so they
// can be tested without a project. They mirror lib/core/providers/user_role_provider.dart.

const NON_MEMBER_ROLES = [
  'deacon', 'deaconess', 'elder', 'pastor', 'finance', 'secretariat',
  'hospitality', 'oversight', 'admin',
];

/** The roles on a user profile (a plain member if there are none). */
function rolesOf(user) {
  if (!user) return ['member'];
  if (Object.prototype.hasOwnProperty.call(user, 'roles')) {
    if (!Array.isArray(user.roles)) return ['member'];
    const r = user.roles.filter((x) => typeof x === 'string');
    return r.length ? r : ['member'];
  }
  return [typeof user.role === 'string' && user.role ? user.role : 'member'];
}

function hasAnyRole(user, wanted) {
  const have = rolesOf(user);
  return wanted.some((r) => have.includes(r));
}

/** Roles that may post announcements (and so read "leaders only" ones). */
const LEADER_ROLES = ['admin', 'secretariat', 'elder', 'deacon', 'deaconess', 'pastor'];

/**
 * Picks recipients from `users` ({uid, ...profile}).
 * @param {Array<{uid: string}>} users
 * @param {{roles?: string[], uids?: string[], everyone?: boolean, exclude?: string[]}} who
 * @returns {string[]} unique uids
 */
function selectRecipients(users, who) {
  const exclude = new Set((who.exclude || []).filter(Boolean));
  const out = new Set();
  for (const u of users) {
    if (!u || !u.uid || exclude.has(u.uid)) continue;
    if (who.everyone) out.add(u.uid);
    else if (who.uids && who.uids.includes(u.uid)) out.add(u.uid);
    else if (who.roles && hasAnyRole(u, who.roles)) out.add(u.uid);
  }
  return [...out];
}

module.exports = { rolesOf, hasAnyRole, selectRecipients, LEADER_ROLES, NON_MEMBER_ROLES };
