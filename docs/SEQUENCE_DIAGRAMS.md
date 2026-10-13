# Sequence Diagrams

Each diagram shows who calls whom, in order. Participant names match the code
(`file.dart` in brackets where helpful).

---

## 1. Sign in and resolve the user's role

```mermaid
sequenceDiagram
    actor U as User
    participant A as AuthScreen
    participant S as AuthService
    participant FA as Firebase Auth
    participant M as BreadOfLifeApp (main.dart)
    participant R as userRoleProvider
    participant FS as Firestore users/uid
    participant Shell as AppShell

    U->>A: enter email + password, press Login or Enter
    A->>A: validate form
    A->>S: signIn(email, password)
    S->>FA: signInWithEmailAndPassword
    FA-->>S: User (uid, email)
    FA-->>M: authStateChanges emits User
    M->>Shell: show AppShell (was AuthScreen)
    Shell->>R: watch role
    R->>FS: snapshots() on users/uid
    FS-->>R: { roles or role }
    R-->>Shell: UserAccess
    Shell->>Shell: build destinations for this role
    Shell-->>U: dashboard, sidebar limited to allowed sections
```

---

## 2. Sign up (always creates a Member)

```mermaid
sequenceDiagram
    actor U as New user
    participant A as AuthScreen
    participant S as AuthService
    participant FA as Firebase Auth
    participant FS as Firestore
    participant Rules as Security rules

    U->>A: name, email, password, Sign Up
    A->>S: signUp(email, password, name)
    S->>FA: createUserWithEmailAndPassword
    FA-->>S: new User
    S->>FS: set users/uid {email, name, role: member}
    FS->>Rules: create users/uid allowed only if role == member and email matches token
    Rules-->>FS: allow
    FS-->>S: ok
    S->>FA: updateDisplayName(name)
    S-->>A: user
    A-->>U: "Account created!"
```

An attempt to sign up with `role: admin` is refused by the rules (tested).

---

## 3. Forgot password

```mermaid
sequenceDiagram
    actor U as User
    participant A as AuthScreen
    participant D as ResetPasswordDialog
    participant S as AuthService
    participant FA as Firebase Auth

    U->>A: tap "Forgot password?"
    A->>D: open (pre-filled with typed email)
    U->>D: confirm email, Send link
    D-->>A: email
    A->>S: sendPasswordReset(email)
    S->>FA: sendPasswordResetEmail
    alt address unknown
        FA-->>S: user-not-found
        S-->>A: (swallowed, so accounts cannot be discovered)
    else address malformed
        FA-->>S: invalid-email
        S-->>A: error
        A-->>U: "That email address does not look right."
    end
    A-->>U: "If an account exists for X, a reset link is on its way."
```

---

## 4. Save a Sunday Income Form (atomic cascade + audit)

The central business transaction. One batch writes the form, its giving records,
its attendance record and the audit entry - all or nothing.

```mermaid
sequenceDiagram
    actor F as Finance officer
    participant Scr as SundayIncomeFormScreen
    participant Calc as SundayIncomeForm (model)
    participant Repo as IncomeFormRepository
    participant B as Firestore WriteBatch
    participant Rules as Security rules
    participant Det as IncomeFormDetailScreen

    F->>Scr: fill counts, forex, cheques, natsave, expenses, attendance, names, signatures
    loop each keystroke
        Scr->>Scr: setState() and recompute live totals + reconciliation
    end
    F->>Scr: Save Form
    Scr->>Scr: validate (attendance and sign-off names required)
    Scr->>Calc: build SundayIncomeForm (categoryBlocks, entries, signature bytes)
    Scr->>Repo: saveAndCascade(form, valuesByKey, actor)
    Repo->>B: set income_forms/newId = form.toMap()
    loop each category with cash
        Repo->>B: set giving/newId_category (amount from counts)
    end
    Repo->>B: set attendance/newId_attendance
    Repo->>B: set audit_log/auto (create, summary, total, actor)
    Repo->>B: commit()
    B->>Rules: evaluate every write in the batch
    Rules-->>B: allow (canManageGiving, own userId, valid action)
    B-->>Repo: committed
    Repo-->>Scr: newId
    Scr->>Det: replace screen with detail view
    Det-->>F: totals, expenses, signatures, Edit/Delete/Print buttons
```

If any single write is refused or the network fails, **nothing** is saved.

---

## 5. Edit a saved form

```mermaid
sequenceDiagram
    actor F as Finance officer
    participant Det as IncomeFormDetailScreen
    participant Scr as SundayIncomeFormScreen (edit mode)
    participant Repo as IncomeFormRepository
    participant B as WriteBatch

    F->>Det: tap Edit (visible only if canManageGiving and form.canEdit)
    Det->>Scr: open with initialForm
    Scr->>Scr: prefill every field, keep saved signatures
    F->>Scr: change counts, Save Form
    Scr->>Repo: updateAndCascade(form, values, previous, actor)
    Repo->>B: set income_forms/id (merge, keep createdAt, add updatedAt)
    loop each category
        alt amount greater than 0
            Repo->>B: set giving/id_category
        else now empty
            Repo->>B: delete giving/id_category
        end
    end
    Repo->>B: set attendance/id_attendance
    Repo->>B: set audit_log (update, "Total A -> B")
    Repo->>B: commit()
    B-->>Repo: committed
    Repo-->>Scr: done
    Scr-->>F: updated detail view
```

---

## 6. Delete a saved form

```mermaid
sequenceDiagram
    actor F as Finance officer
    participant Det as IncomeFormDetailScreen
    participant Dlg as Confirm dialog
    participant Repo as IncomeFormRepository
    participant B as WriteBatch

    F->>Det: tap Delete
    Det->>Dlg: "Delete this form? This also removes the giving and attendance records it created."
    alt user cancels
        Dlg-->>Det: false
        Det-->>F: nothing changes
    else user confirms
        Dlg-->>Det: true
        Det->>Repo: deleteAndCascade(form, values, actor)
        Repo->>B: delete giving/id_* (all 5 categories)
        Repo->>B: delete attendance/id_attendance
        Repo->>B: delete income_forms/id
        Repo->>B: set audit_log (delete, "Total was X")
        Repo->>B: commit()
        B-->>Repo: committed
        Det-->>F: back to list, "Form deleted."
    end
```

The audit entry survives the deletion, nobody can edit or remove it.

---

## 7. Print or download a PDF (with fallback)

```mermaid
sequenceDiagram
    actor U as User
    participant Scr as Detail / Summary / My Giving screen
    participant PA as pdf_actions (printPdf, downloadPdf)
    participant PDF as buildXxxPdf()
    participant P as printing package
    participant Br as Browser

    U->>Scr: tap Print
    Scr->>PA: printPdf(filename, build)
    PA->>P: layoutPdf(onLayout: build) with 20 s timeout
    P->>PDF: build()
    PDF-->>P: PDF bytes
    P->>Br: hidden frame + window.print()
    alt print dialog opens
        Br-->>U: browser print window
    else it fails or times out
        P-->>PA: error / timeout
        PA-->>U: snackbar "The print dialog did not open, so the PDF was downloaded"
        PA->>P: sharePdf(bytes, filename)
        P->>Br: temporary download link click
        Br-->>U: file saved
    end
```

---

## 8. Draw a signature

```mermaid
sequenceDiagram
    actor S as Signer
    participant Pad as SignaturePadField
    participant Ctl as SignatureController
    participant Scr as SundayIncomeFormScreen

    S->>Pad: finger or mouse down on the box
    Pad->>Scr: onDrawingChanged(true)
    Scr->>Scr: ListView physics = NeverScrollable (page holds still)
    loop while moving
        Pad->>Ctl: addPoint
    end
    S->>Pad: lift
    Pad->>Scr: onDrawingChanged(false)
    Scr->>Scr: scrolling re-enabled
    S->>Scr: Save Form
    Scr->>Ctl: isEmpty?
    alt strokes present
        Scr->>Ctl: toPngBytes()
        Ctl-->>Scr: PNG
        Scr->>Scr: store on form (saved as base64)
    else nothing drawn
        Scr->>Scr: keep previously saved signature, if any
    end
```

---

## 9. Monthly or yearly summary

```mermaid
sequenceDiagram
    actor U as Finance officer
    participant Scr as PeriodSummaryScreen
    participant GP as givingRecordsProvider
    participant FP as incomeFormsProvider
    participant PS as PeriodSummary.compute
    participant PDF as buildPeriodSummaryPdf

    U->>Scr: open Summary, choose Month or Year, use arrows
    Scr->>GP: watch (live stream)
    Scr->>FP: watch (live stream)
    GP-->>Scr: all giving records
    FP-->>Scr: all forms
    Scr->>PS: compute(start, isYear, records, forms)
    PS-->>Scr: category totals, weekly rows, bank/expense totals, attendance
    Scr-->>U: render
    U->>Scr: Download PDF
    Scr->>PDF: build(summary)
    PDF-->>U: summary PDF
```

---

## 10. Export to CSV

```mermaid
sequenceDiagram
    actor U as Finance officer
    participant Scr as ExportScreen
    participant Exp as giving_export (givingCsv / incomeFormsCsv)
    participant Csv as toCsv
    participant DL as fileDownloaderProvider
    participant Br as Browser

    U->>Scr: choose year, tap CSV
    Scr->>Scr: filter records or forms to the year
    Scr->>Exp: givingCsv(list) or incomeFormsCsv(list, values)
    Exp->>Csv: rows
    Csv-->>Exp: text with BOM, quoted cells, formula guard
    Exp-->>Scr: csv
    Scr->>DL: (filename, csv)
    DL->>Br: Blob + temporary link click
    Br-->>U: giving-2026.csv saved
```

---

## 11. A forbidden action is refused by the server

Hiding buttons is not security. This shows the real barrier.

```mermaid
sequenceDiagram
    actor M as Member (no finance role)
    participant App as Any client code
    participant FS as Firestore
    participant Rules as Security rules
    participant UD as users/uid

    M->>App: (hypothetically) attempt to read giving or write an income form
    App->>FS: query / write
    FS->>Rules: evaluate with request.auth.uid
    Rules->>UD: get roles for this uid
    UD-->>Rules: roles = member
    Rules-->>FS: deny (not Admin, Finance or Oversight)
    FS-->>App: permission-denied
    App-->>M: error shown, no data returned
```

---

## 12. Live totals while typing (reconciliation)

```mermaid
sequenceDiagram
    actor F as Finance officer
    participant Tf as Denomination TextFormField
    participant State as _SundayIncomeFormScreenState
    participant UI as Totals card + warning banner

    F->>Tf: type a count
    Tf->>State: onChanged() then setState()
    State->>State: _denominationTotal(controllers) for each table
    State->>State: grand = cash + forex + cheques
    State->>State: variance = (reserve - expenses) - 20% of tithe
    State->>UI: rebuild
    alt |variance| less than or equal to 0.01
        UI-->>F: no banner
    else
        UI-->>F: gold warning with expected, actual and variance
    end
```
