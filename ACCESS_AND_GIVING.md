# Account roles and private giving

New accounts still register as Members. No one can select Finance, Oversight,
Hospitality, or Admin during public sign-up.

Admins use **Account Roles** (under More on smaller screens) to assign multiple
responsibilities. Existing profiles with `role` continue to work. Once `roles`
is present, that array is authoritative; the legacy field does not restore
revoked access. For example, `roles: ['finance', 'elder']` grants both duties.

| Role | Access added |
| --- | --- |
| Hospitality | Register and maintain church directory entries |
| Secretariat | Existing directory, attendance and event permissions |
| Finance | Record giving, link individual contributions, view income reports |
| Financial Oversight | View giving, weekly statements and income forms; no financial edits |
| Leadership | Existing attendance, announcements and prayer permissions |
| Admin | Manage role assignments and all existing management functions |
| Every signed-in member | Private My Giving history |

Hospitality registration means directory entries, not creating passwords or
assigning permissions. Members create their own app accounts. No real account
roles were changed as part of this implementation.

## Personal contributions

Finance chooses the contributor's registered account when recording a named
contribution. Verify the person's identity and email before linking. `memberUserId`
is the authentication account ID; matching names never grants access. New named
entries record `recordedBy`. Finance can link older unlinked individual entries
using the link icon; the linking account is saved as `linkedBy`.

Service totals and cash-count records cannot be linked to an individual. Legacy
unlinked entries remain visible only to Finance, Admin and Oversight. No automatic
name-based migration runs. My Giving supports date ranges and a tithe-only filter,
shows totals separately per currency, and provides references for reporting
discrepancies to Finance. It does not let members edit recorded contributions.

The financial overview covers the existing income ledger and reports. Expense
tracking, bank reconciliation, balances and a complete immutable audit log are
not included in this change. Do not enter the same income both individually and
again as a service total; the existing ledger does not reconcile duplicates.

## Release

Deploy the reviewed `firestore.rules` to the intended Firebase project before
releasing the updated app. The old rules do not support multiple roles or private
giving queries. These source changes do not themselves publish rules or grant
any production account access. Coordinate the app update and role assignments:
older clients do not understand combined responsibilities.

Run Flutter tests and source analysis. Run the Firestore rules suite with a
compatible Firebase CLI and Java runtime:

    cd rules-tests
    firebase emulators:exec --only firestore --project demo-church-access "node rules.test.mjs"

The emulator suite uses a demo project and never production data.
