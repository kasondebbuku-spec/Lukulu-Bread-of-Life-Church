# Phone notifications: what is built and what is left to switch on

The app can send **real phone notifications**: a message that appears on a locked
phone, even when the app is closed. The code for this is finished and tested, but
it does nothing until the three steps below are done. Until then the app hides the
"Get alerts on this phone" card, so it is safe to publish the app first.

## What people get

| Who | Told about |
|---|---|
| Pastor and Admin | a leader sent a **ministry report** |
| The leader | their report was **reviewed** (with the Pastor's reply) |
| Admin | someone asked for a **role** or a **ministry position** |
| Finance, Financial Oversight, Pastor, Admin | a **Sunday income form was saved** (who and when, never an amount) |
| Everyone | a new **event**; a new **announcement** (leaders only for a leaders-only one) |

The person who caused a change is not told about their own change.

Each person turns alerts on **per phone or browser**: **Notifications (the bell) ->
Turn on alerts**, then **Allow** in the browser's prompt. Signing out turns alerts
off for that phone, so the next person to use it does not get your alerts.

On an **iPhone**, alerts work only when the app has been added to the Home Screen
(Share -> Add to Home Screen) and opened from there. Android Chrome works in the
browser or when installed.

## Three things only you can do

1. **Upgrade the Firebase project to the Blaze (pay as you go) plan.** Sending needs
   a small server program (Cloud Functions), which Firebase only runs on Blaze. It
   asks for a card. At the size of a church the usage stays inside the free monthly
   allowance, but set a **budget alert** (Google Cloud console -> Billing -> Budgets)
   so you are told if that ever changes.
2. **Create the Web Push key.** Firebase console -> Project settings -> **Cloud
   Messaging** -> **Web Push certificates** -> **Generate key pair**. Copy the key
   (a long text starting with `B`) and paste it between the quotes in
   `lib/core/push/push_config.dart` (`const pushVapidKey = '...';`). It is a public
   key, safe to keep in the code.
3. **Tell Claude to deploy.** The order is: Firestore rules, then the functions
   (`firebase deploy --only functions`), then the app (hosting).

## How it works (for whoever maintains it)

* `web/firebase-messaging-sw.js` is the background worker that shows notifications.
* A phone that turned alerts on is listed in `push_tokens/{address}` with the
  person's id. People can only add, move and remove their own entries (see
  `firestore.rules`).
* `functions/index.js` has one trigger per event above. The choice of people is in
  `functions/lib/recipients.js`, the wording in `functions/lib/messages.js` and the
  sending in `functions/lib/send.js`. Run the checks with `cd functions && node --test`.
* Notifications that fail never break the change that caused them, and phones that no
  longer exist are removed from the list automatically.
* Not included yet: pledge due-date reminders on the phone (they still appear on Home
  and in the bell), and choosing which kinds of alert you want.
