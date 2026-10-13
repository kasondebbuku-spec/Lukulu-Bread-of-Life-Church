# Design Patterns and Principles

This document follows the approach of Craig Larman's *Applying UML and Patterns*:
assign responsibilities deliberately (the **GRASP** principles), then name the
patterns that result. For each item it states **where it lives in the code**,
**why it helps here**, and, where honest, **where the code falls short**.

---

## Part 1 - GRASP

### 1. Information Expert
*Give a responsibility to the class that has the information needed to fulfil it.*

| Where | How |
|---|---|
| `SundayIncomeForm` (`models/sunday_income_form.dart`) | It owns the counts, entries and names, so it computes `grandTotal`, `twentyPercentOfTithe`, `natsaveDeposit`, `totalCollection`, `reconciliationVariance`, `isReconciled`, `attendanceTotal`. |
| `CategoryBlock.amount()` | The block holding a denomination breakdown computes its own amount. |
| `ForexEntry.kwachaValue` | The entry holding currency and amount converts itself. |
| `UserAccess` / `UserRole` (`core/providers/user_role_provider.dart`) | The role knows what it may do (`canManageGiving`); `UserAccess` combines several roles with `any`. |
| `WeekSummary`, `WeekIncomeFormTotals`, `PeriodSummary`, `MemberGivingStatement` | Each knows the records it summarises and the rule for grouping them. |

**Benefit:** totals are *derived on demand*, never stored twice, so they cannot
disagree with the counts. The paper form works the same way (its cells are
formulas).

### 2. Creator
*Make B create A if B contains, records, closely uses or has the data to initialise A.*

| Where | How |
|---|---|
| `IncomeFormRepository._writeCascade` | The repository creates the `GivingRecord`s and `AttendanceRecord` that derive from a form, because it holds the form and the unit of work. |
| `AuditEntry.newEntry` | The entry type builds its own document, so every writer produces the same shape. |
| `MemberGivingStatement.compute`, `PeriodSummary.compute` | Factory-style constructors that build the aggregate from raw records. |
| `SundayIncomeForm.fromDoc` | The entity creates itself from a stored document and back-fills defaults for older ones. |

### 3. Controller
*Assign handling of a system event to a non-UI object that represents the use case.*

| Where | How |
|---|---|
| `IncomeFormRepository.saveAndCascade / updateAndCascade / deleteAndCascade` | These are the use-case controllers for "save / edit / delete a Sunday Income Form": the screen delegates and does not orchestrate writes. |
| `AuthService` | Controller for sign in, sign up, reset and sign out. |
| Riverpod providers | Receive "role changed", "data changed" events and expose results to screens. |

**Falls short:** `SundayIncomeFormScreen` still does form validation, converts
controllers to a `SundayIncomeForm` and decides edit-vs-create. A dedicated
`SundayIncomeFormController` (a `Notifier`) would make the screen purely
presentational and the flow unit-testable without widgets.

### 4. Low Coupling
*Keep dependencies few and weak.*

| Where | How |
|---|---|
| Screens use providers and models, never `FirebaseFirestore` | Replace the backend and only `repositories/` change. |
| `fileDownloaderProvider` | Screens do not know how a download happens; tests inject a fake. |
| `pdf_actions.dart` | Print/download logic lives once; screens pass only a filename and a builder. |
| `FirestoreCollections` | Collection names are constants, not repeated strings. |
| `auditActorProvider` | The repository receives an `AuditActor` value, not Firebase Auth. |

### 5. High Cohesion
*Keep each class focused on one purpose.*

| Where | How |
|---|---|
| `features/dashboard/widgets/*` | `HeroBanner`, `UpcomingEventsCard`, `QuickAccessCard`, `DailyVerseCard`, `DashboardHeader`, `DashboardPanel` each do one thing. |
| One repository per collection | `MembersRepository`, `GivingRepository`, `AuditRepository`, ... |
| `SignaturePadField` | One reusable widget for drawing a signature. |
| Calculators separate from UI | `PeriodSummary` etc. are pure Dart. |

**Falls short:** `SundayIncomeFormScreen` (about 900 lines) and `GivingScreen` do too
much; see the recommendations at the end.

### 6. Polymorphism
*Vary behaviour by type with polymorphic operations, not conditionals.*

| Where | How |
|---|---|
| `FirestoreRepository<T>` subclasses | Each overrides `fromDoc` / `toMap` (and sometimes `watchAll`); callers use the same interface. |
| `file_download.dart` conditional export | `file_download_web.dart` and `file_download_stub.dart` implement the same function for different platforms. |
| `AuditAction.label`, `ServiceType.label`, `GivingCategory.label` | Behaviour attached to the enum value. |
| `AuditRepository.toMap` | Overridden to *refuse* writes, enforcing immutability through the type. |

### 7. Pure Fabrication
*Invent a class that is not a domain concept when it keeps the design cohesive and coupled lightly.*

| Where | Why it is fabricated |
|---|---|
| `WeekSummary`, `WeekIncomeFormTotals`, `PeriodSummary`, `MemberGivingStatement` | "A month's summary" is not a thing in the church; these classes exist to keep reporting logic out of screens and entities. |
| `toCsv`, `givingCsv`, `incomeFormsCsv` | Serialisation concerns kept out of the model. |
| `buildIncomeFormPdf`, `buildPeriodSummaryPdf`, `buildMemberStatementPdf` | Presentation-of-record concerns kept out of the model. |
| `UserAccess` | Combines roles; not in the paper world. |
| `greetingFor`, `verseForDate` | Tiny deterministic helpers, trivially testable. |

### 8. Indirection
*Insert an intermediary to decouple two things.*

| Where | Between |
|---|---|
| Riverpod providers | screens <-> repositories |
| `AuthService` | screens <-> Firebase Auth |
| `fileDownloaderProvider` | screens <-> browser download API |
| `displayNameProvider` | screens <-> "which name do we show" (profile, then auth, then email) |
| `FirestoreRepository` | everything <-> the Firestore SDK |

### 9. Protected Variations
*Wrap points of likely change behind a stable interface.*

| Likely change | Protection |
|---|---|
| Firestore documents evolve | `fromDoc` back-fills defaults and treats unknown categories as `null` ("Uncategorized"); new `SundayIncomeForm` fields default to empty so old forms still load; `recordsKeyedById` flag marks the newer record scheme. |
| Banknote set changes (K500/K200 added) | One list, `zmwDenominations`; every screen, PDF and export iterates it, so the change was one edit. |
| Platform (web vs other) | Conditional import for downloads. |
| Browser PDF viewer unavailable | Print falls back to download. |
| Brand colours | `AppColors` tokens; no hard-coded hues in screens. |
| Authorisation rules | Server-side `firestore.rules`, tested separately from UI. |
| Backend identity of the actor | `AuditActor` value type. |

---

## Part 2 - Classic and enterprise patterns in use

| Pattern | Intent | Where | Evidence |
|---|---|---|---|
| **Repository** | Hide persistence behind a collection-like interface | `repositories/*`, `core/repositories/firestore_repository.dart` | Providers expose repositories; screens never see Firestore |
| **Template Method** | Fix an algorithm's skeleton, let subclasses fill steps | `FirestoreRepository` (`watchAll`, `add`, `update`, `delete` call abstract `fromDoc` / `toMap`) | Eight subclasses |
| **Factory Method** | Construct objects via named creators | `fromDoc`, `fromData`, `compute`, `fromForms`, `AuditEntry.newEntry` | Round-trip and compute tests |
| **Adapter** | Convert one interface to another | Repositories adapt Firestore documents to domain objects | `fromDoc` / `toMap` |
| **Observer** | Notify dependants of change | Firestore `snapshots()` streams consumed through Riverpod; screens rebuild live | Dashboard counts update without refresh |
| **Dependency Injection** | Supply collaborators from outside | Riverpod `Provider`s; constructor injection in `AuthService`, `IncomeFormRepository` | Tests override providers with fakes |
| **Facade** | Simple interface to a complex subsystem | `AuthService` over `FirebaseAuth` + `Firestore` profile creation; `pdf_actions` over `printing` | `signUp` creates account and profile in one call |
| **Unit of Work** | Commit a set of changes atomically | Firestore `WriteBatch` in `saveAndCascade`, `updateAndCascade`, `deleteAndCascade` | Rules tests: "finance CAN edit a form and its derived records in one batch" |
| **Value Object / Immutable entity** | Equality by value; no mutation | `ForexEntry`, `ChequeEntry`, `ExpenseEntry`, `ZmwDenomination`, `AuditActor`, `CategoryBlock` | `const` constructors, final fields |
| **Special Case / Null Object** | A harmless default instead of null | `UserAccess.member`; empty `CategoryBlock`; `EmptyState` widget | Missing role resolves to least privilege |
| **Event log (append-only)** | Keep an immutable history of changes | `audit_log` collection and `AuditEntry` | Rules: nobody can update or delete; written in the same batch |
| **Composition over inheritance** | Build behaviour from parts | `SundayIncomeForm` composed of blocks and entries; dashboard from cards | |
| **Strategy (light)** | Interchangeable algorithms | `FileDownloader` typedef (real vs fake); platform download implementations | Export screen test injects a fake |
| **Single Source of Truth** | One authoritative copy of a fact | Denominations, collection names, brand colours, daily verses | |

---

## Part 3 - Design heuristics applied

- **Derive, do not duplicate.** Stored facts are counts; every total is computed.
- **Make illegal states hard to represent.** Roles are an enum; unknown role text
  becomes `member`; self-signup cannot request a higher role.
- **Fail closed.** A malformed `roles` field grants nothing (`UserAccess.fromData`).
- **Atomicity for related writes.** A form, its derived records and its audit entry
  commit together.
- **Server enforces, client assists.** UI hides actions; `firestore.rules` decides.
- **Test the rules, not just the screens.** 70 emulator tests exercise every role.
- **Prefer small pure functions for money.** They are the easiest code to prove right.

---

## Part 4 - Honest assessment and recommended refactors

| # | Issue | Principle affected | Suggested remedy |
|---|---|---|---|
| 1 | `SundayIncomeFormScreen` mixes state, validation, assembly of the form and layout | High Cohesion, Controller | Extract a `SundayIncomeFormController` (Riverpod `Notifier`) holding the draft; keep the screen presentational |
| 2 | `userRoleProvider` and `userProfileNameProvider` read Firestore directly | Low Coupling, Indirection | Add a `UserProfileRepository`; both providers use it |
| 3 | Money is held as `double`, with a 0.01 tolerance in `isReconciled` | Protected Variations | Introduce a `Money` value object storing whole **ngwee** (integers); convert at the edges |
| 4 | Permission logic exists twice (Dart getters and `firestore.rules`) | Single Source of Truth | Keep both (the server must enforce) but add a test matrix that runs the same role/action table against each |
| 5 | `models` and `core` reference each other slightly (`AuditActor`) | Low Coupling | Move `AuditActor` into `core` |
| 6 | Forms saved before keyed records are read-only | Protected Variations | A one-off migration that renames derived records and sets `recordsKeyedById` |
| 7 | Audit log covers Sunday Income Forms only | Completeness | Reuse `AuditEntry` for giving, members and role changes |
| 8 | PDF uses ASCII-only text | Protected Variations | Bundle a Unicode font if non-English names must print |
| 9 | Large `GivingScreen` (dialogs, list, actions) | High Cohesion | Split dialogs and list items into widgets |

These are improvements to schedule, not defects that affect correctness today:
the money logic is unit-tested against the real paper form's figures.

---

## Part 5 - Mapping tests to design

| Concern | Test file |
|---|---|
| Information Expert (form maths, reconciliation) | `sunday_income_form_natsave_test.dart` |
| Creator / Factory (period, statement, weekly roll-ups) | `period_summary_test.dart`, `member_statement_test.dart`, `week_income_form_totals_test.dart` |
| Unit of Work and Controller wiring | `income_form_edit_test.dart`, rules tests (`rules-tests/rules.test.mjs`) |
| Event log | `audit_log_test.dart` and the `audit_log` rules tests |
| Protected Variations (CSV safety, PDF characters, platform download) | `csv_export_test.dart`, `income_form_print_test.dart` |
| Polymorphism / role behaviour | `user_access_test.dart`, `navigation_access_test.dart`, `financial_oversight_test.dart` |
| Cohesive widgets, responsive layout | `dashboard_layout_test.dart`, `signature_test.dart`, `sunday_income_form_scroll_test.dart` |
