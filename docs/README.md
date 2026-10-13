# Bread of Life Church (Lukulu) - Documentation

Church management web app: members, attendance, giving and finances, events,
announcements and prayer requests. Live at **https://lukulu-bread-of-life.web.app**.

| Document | Audience | What it covers |
|---|---|---|
| [USER_MANUAL.md](USER_MANUAL.md) | Church staff and members | How to use every part of the app, by task and by role |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Developers, reviewers | System context, layers, data model, security, deployment, testing |
| [SEQUENCE_DIAGRAMS.md](SEQUENCE_DIAGRAMS.md) | Developers | Step-by-step flows: sign-in, saving/editing/deleting a form, printing, export |
| [UML.md](UML.md) | Developers, analysts | Use cases, domain model, class diagrams, state and activity diagrams |
| [DESIGN_PATTERNS.md](DESIGN_PATTERNS.md) | Developers | GRASP principles and design patterns (after Craig Larman) as applied here, with where each lives in the code, and where it falls short |

## Diagram notation

Diagrams use [Mermaid](https://mermaid.js.org/), which GitHub renders directly in
Markdown. If you view these files somewhere that shows the raw text, paste a
diagram block into <https://mermaid.live> to see it.

## Quick facts

- **Stack:** Flutter (web), Dart, Riverpod, Firebase Auth, Cloud Firestore, Firebase Hosting.
- **Repository:** `kasondebbuku-spec/Lukulu-Bread-of-Life-Church` (GitHub).
- **Firebase project:** `kasonde-bbuku`.
- **Currency:** Zambian Kwacha (ZMW); denominations K500 down to 5 ngwee.
- **Brand colours:** purple, gold and blue only.
- **Source of truth for server-side permissions:** `firestore.rules` (tested by `rules-tests/`).
