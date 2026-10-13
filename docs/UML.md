# UML

Models of the system from the requirements side (use cases, domain model) to the
design side (classes, states, activities).

## 1. Use cases

```mermaid
flowchart LR
    member(["Member"])
    leader(["Church leader"])
    sec(["Secretariat"])
    hosp(["Hospitality"])
    fin(["Finance Officer"])
    over(["Financial Oversight"])
    adm(["Admin"])

    subgraph sys["Church app"]
        uc1(["Sign up / sign in / reset password"])
        uc2(["View dashboard and events"])
        uc3(["Submit and view own prayer requests"])
        uc4(["View own giving and download yearly statement"])
        uc5(["Read announcements"])
        uc6(["Post announcements"])
        uc7(["View all prayer requests"])
        uc8(["Record attendance"])
        uc9(["Manage members directory"])
        uc10(["Manage events"])
        uc11(["Record a Sunday Income Form"])
        uc12(["Edit or delete a form"])
        uc13(["Record a single contribution and link to a member"])
        uc14(["Print or download PDFs and reports"])
        uc15(["Weekly statement, monthly and yearly summary"])
        uc16(["Export data to CSV"])
        uc17(["View financial records and Activity log"])
        uc18(["Assign roles to accounts"])
    end

    member --> uc1 & uc2 & uc3 & uc4 & uc5
    leader --> uc1 & uc2 & uc6 & uc7 & uc8
    sec --> uc9 & uc10 & uc6 & uc7 & uc8
    hosp --> uc9
    fin --> uc11 & uc12 & uc13 & uc14 & uc15 & uc16 & uc17
    over --> uc17 & uc15 & uc14 & uc16
    adm --> uc18 & uc9 & uc10 & uc11 & uc12 & uc13 & uc17
```

Notes: every actor can also do the Member use cases. Admin can do everything the
Finance Officer can (use cases 11-17 above). Oversight is **read-only** (it sees
reports and the log but has no create, edit or delete). Hospitality manages only the
members directory.

### Use case: Record a Sunday Income Form (fully dressed)

| | |
|---|---|
| **Primary actor** | Finance Officer (or Admin) |
| **Stakeholders** | Pastor (needs an accurate filed copy); Congregation (trust); Auditors |
| **Preconditions** | Actor is signed in with the Finance or Admin role |
| **Trigger** | Cash from a service has been counted |
| **Main success scenario** | 1. Open Giving, choose Sunday Income Form. 2. Pick the Sunday and service. 3. Enter note/coin counts per category. 4. Enter forex and cheques. 5. Enter Natsave and expenses-reserve counts and the expenses list. 6. Enter attendance and sign-off names; optionally draw signatures. 7. System shows live totals and reconciliation status. 8. Actor saves. 9. System atomically stores the form, one giving record per category, one attendance record and an audit entry. 10. System shows the saved form. |
| **Extensions** | 7a. Reserve minus expenses is not 20% of tithe: warning shown; actor may correct or save anyway. 8a. Required field missing: save is blocked with a message. 9a. Write refused or network fails: nothing is saved, error shown. |
| **Postconditions** | Form, derived records and audit entry exist, or none do |
| **Special requirements** | Amounts derived from counts; ASCII-safe PDF; works on phone and desktop |

## 2. Domain model (conceptual)

```mermaid
classDiagram
    direction LR
    class Account {
        email
        name
        roles
    }
    class UserAccess {
        roles
        canManageGiving()
        canViewGiving()
        canManageMembers()
        canManageAttendance()
    }
    class UserRole {
        <<enumeration>>
        member
        deacon
        deaconess
        elder
        pastor
        finance
        secretariat
        hospitality
        oversight
        admin
    }
    class Member {
        name
        email
        phone
    }
    class GivingRecord {
        memberName
        amount
        currency
        date
        category
        denominationBreakdown
    }
    class GivingCategory {
        <<enumeration>>
        tithe
        offering
        seed
        thanksgiving
        pledge
    }
    class SundayIncomeForm {
        date
        service
        men
        women
        children
        preparedBy
        checkedBy
        collectedBy
        grandTotal()
        twentyPercentOfTithe()
        natsaveDeposit()
        totalCollection()
        reconciliationVariance()
        isReconciled()
    }
    class CategoryBlock {
        denominationBreakdown
        amount()
    }
    class ForexEntry {
        currency
        amount
        kwachaValue()
    }
    class ChequeEntry {
        name
        chequeNo
        amount
    }
    class ExpenseEntry {
        description
        amount
    }
    class AttendanceRecord {
        date
        count
        newVisitors
        men
        women
        children
    }
    class AuditEntry {
        action
        entity
        summary
        detail
        userName
        createdAt
    }
    class ChurchEvent {
        title
        date
        location
    }
    class Announcement {
        title
        content
        targetAudience
    }
    class PrayerRequest {
        request
    }

    Account "1" --> "1" UserAccess : has
    UserAccess "1" o-- "1..*" UserRole
    GivingRecord --> GivingCategory
    GivingRecord "0..*" --> "0..1" Account : linked to
    SundayIncomeForm "1" *-- "5" CategoryBlock : counts per category
    SundayIncomeForm "1" *-- "1" CategoryBlock : natsave
    SundayIncomeForm "1" *-- "1" CategoryBlock : expenses reserve
    SundayIncomeForm "1" *-- "0..*" ForexEntry
    SundayIncomeForm "1" *-- "0..*" ChequeEntry
    SundayIncomeForm "1" *-- "0..*" ExpenseEntry
    SundayIncomeForm "1" ..> "0..5" GivingRecord : creates
    SundayIncomeForm "1" ..> "1" AttendanceRecord : creates
    AuditEntry "0..*" --> "1" Account : performed by
    AuditEntry "0..*" ..> "1" SundayIncomeForm : records changes to
    PrayerRequest "0..*" --> "1" Account : submitted by
```

## 3. Design class diagram: data access and state

```mermaid
classDiagram
    direction TB
    class FirestoreRepository~T~ {
        <<abstract>>
        +collectionPath
        +fromDoc(doc) T
        +toMap(item) Map
        +watchAll() Stream
        +add(item)
        +update(id, item)
        +delete(id)
    }
    class MembersRepository
    class GivingRepository {
        +watchForMember(uid)
    }
    class AttendanceRepository
    class EventsRepository
    class AnnouncementsRepository {
        +watchAllForRole(role)
    }
    class PrayerRepository {
        +watchFiltered(userId, seeAll)
    }
    class IncomeFormRepository {
        +saveAndCascade(form, values, actor)
        +updateAndCascade(form, values, previous, actor)
        +deleteAndCascade(form, values, actor)
        +givingRecordId(formId, category)$
        +attendanceRecordId(formId)$
    }
    class AuditRepository {
        +watchAll() newest 300
    }
    class AuthService {
        +signIn()
        +signUp()
        +sendPasswordReset()
        +signOut()
    }

    FirestoreRepository <|-- MembersRepository
    FirestoreRepository <|-- GivingRepository
    FirestoreRepository <|-- AttendanceRepository
    FirestoreRepository <|-- EventsRepository
    FirestoreRepository <|-- AnnouncementsRepository
    FirestoreRepository <|-- PrayerRepository
    FirestoreRepository <|-- IncomeFormRepository
    FirestoreRepository <|-- AuditRepository

    class repository_providers {
        <<Riverpod providers>>
        membersProvider
        givingRecordsProvider
        incomeFormsProvider
        auditLogProvider
        weekSummaryProvider
    }
    class userRoleProvider {
        <<StreamProvider of UserAccess>>
    }
    class displayNameProvider
    class auditActorProvider

    repository_providers ..> MembersRepository : creates
    repository_providers ..> GivingRepository : creates
    repository_providers ..> IncomeFormRepository : creates
    repository_providers ..> AuditRepository : creates
    IncomeFormRepository ..> AuditRepository : writes entries in same batch
    auditActorProvider ..> displayNameProvider
```

## 4. Design class diagram: calculators

Pure Dart classes that turn stored facts into figures. None of them touches Flutter
or Firebase.

```mermaid
classDiagram
    direction LR
    class SundayIncomeForm {
        +grandTotal(values)
        +twentyPercentOfTithe(values)
        +natsaveDeposit(values)
        +reconciliationVariance(values)
        +isReconciled(values)
    }
    class WeekSummary {
        +compute(sunday, records)
        +grandTotal
    }
    class WeekIncomeFormTotals {
        +compute(sunday, forms, values)
        +fromForms(forms, values)
        +totalCollection
    }
    class PeriodSummary {
        +compute(start, isYear, records, forms, values)
        +grandTotal
        +averageAttendance
    }
    class MemberGivingStatement {
        +compute(memberName, year, records)
        +yearsWithGiving(records)$
    }
    class CurrencyStatement {
        total
        byMonth
        byCategory
    }
    class CsvExport {
        +givingCsv(records)
        +incomeFormsCsv(forms, values)
    }
    class Csv {
        +toCsv(rows)
    }

    WeekIncomeFormTotals ..> SundayIncomeForm : sums
    PeriodSummary *-- WeekIncomeFormTotals
    PeriodSummary ..> WeekSummary : same idea per period
    MemberGivingStatement *-- CurrencyStatement
    CsvExport ..> Csv
    CsvExport ..> SundayIncomeForm
```

## 5. State diagram: life of a Sunday Income Form

```mermaid
stateDiagram-v2
    [*] --> Entering : open form
    Entering --> Entering : type counts (live totals)
    Entering --> Discarded : leave without saving
    Entering --> Saved : Save (validation passes, batch commits)
    Entering --> Entering : Save fails (nothing stored)

    Saved --> Editing : Edit (Finance or Admin)
    Editing --> Saved : Save (records updated, audit entry)
    Editing --> Saved : leave without saving
    Saved --> Deleted : Delete and confirm (records removed, audit entry)

    Saved --> ReadOnly : form predates keyed records
    ReadOnly --> [*]
    Discarded --> [*]
    Deleted --> [*]
```

### Reconciliation state (inside Entering, Editing and Saved)

```mermaid
stateDiagram-v2
    [*] --> Balanced
    Balanced --> Unbalanced : variance beyond 1 ngwee
    Unbalanced --> Balanced : counts or expenses corrected
    note right of Unbalanced
        Gold warning shown on entry, detail,
        weekly statement, summary and PDF.
        Saving is still allowed.
    end note
```

## 6. Activity diagram: filling in the form

```mermaid
flowchart TD
    start([Start]) --> open[Open Sunday Income Form]
    open --> pick[Choose Sunday and service]
    pick --> count[Count notes and coins per category]
    count --> extra[Add forex and cheques if any]
    extra --> bank[Count Natsave deposit and expenses reserve]
    bank --> exp[List expenses]
    exp --> check{Reserve minus expenses<br/>equals 20 percent of tithe?}
    check -- yes --> att[Enter attendance and sign-off names]
    check -- no --> fix{Counting mistake?}
    fix -- yes --> count
    fix -- no genuine difference --> att
    att --> sign[Optionally draw signatures]
    sign --> save[Save form]
    save --> ok{Saved?}
    ok -- no --> err[Show error, nothing stored] --> save
    ok -- yes --> detail[Show saved form]
    detail --> out{Need a copy?}
    out -- yes --> pdf[Print or download PDF]
    out -- no --> done([End])
    pdf --> done
```

## 7. Package / component view

```mermaid
flowchart TB
    subgraph features["features/*"]
        dash["dashboard"]
        giv["giving"]
        mem["members"]
        att["attendance"]
        evt["events"]
        ann["announcements"]
        pry["prayer"]
    end
    nav["navigation"]
    auth["screens/auth + services/AuthService"]
    models["models"]
    repos["repositories"]
    core["core: providers, utils, widgets, theme, constants"]

    nav --> features
    nav --> core
    features --> models
    features --> repos
    features --> core
    repos --> models
    repos --> core
    auth --> core
    models --> core
    core -.->|"audit actor type"| models
```

Dependencies point downward almost everywhere, which keeps business rules reusable
and testable. There is one small upward link: `core/providers/audit_actor_provider.dart`
imports the `AuditActor` type from `models`, while `models` use `core/utils` helpers
(a mild cycle between two low-level packages; moving `AuditActor` into `core` would
remove it).
