# P0 device smoke test (items 5 & 6)

Run after deploying functions, rules, and seeding transport coverage.

## Prerequisites

- Two physical devices (or one phone + simulator for in-app only; **push requires a physical iPhone**)
- Two accounts in the **same family** (one family member, one volunteer account optional)
- Latest app build: `flutter run` on each device
- Cloud Functions deployed to `care-signal-ai`
- `config/transport_coverage` seeded (see below)

## Quick verify: transport coverage (item 5)

1. Sign in on any device.
2. Menu → **Volunteers** → **Transportation** (Request a ride).
3. Enter ZIP `94102` → green banner with **San Francisco Bay Area**.
4. Enter ZIP `90210` → orange “No volunteer drivers near…” banner.
5. In [Firebase Console](https://console.firebase.google.com/project/care-signal-ai/firestore/data/config/transport_coverage), change `regionName` to `Test Region` → banner updates without app restart.

## Smoke test A — Family message push

| Step | Actor | Action | Expected |
|------|-------|--------|----------|
| 1 | User A (phone) | Sign in, stay in app on Home | — |
| 2 | User B (phone) | Sign in, open **Family messages**, send DM to A | — |
| 3 | User A | Background the app (home button) | Push notification within ~30s |
| 4 | User A | Tap notification | Opens chat with B |
| 5 | User A | Open **Notifications** | Inbox row for family message |

## Smoke test B — Volunteer request lifecycle

| Step | Actor | Action | Expected |
|------|-------|--------|----------|
| 1 | Family | **Volunteers** → request respite (or transport) | Request created |
| 2 | Volunteer | Check **Notifications** + push | New request alert |
| 3 | Volunteer | Tap → request detail | Accept or propose counter |
| 4 | Family | **Notifications** | Accept/counter/completed update |
| 5 | Family | Tap notification | Opens family request detail |

## Smoke test C — Risk alert

| Step | Actor | Action | Expected |
|------|-------|--------|----------|
| 1 | Member A | **Daily Check-in** with score **below 55** | Saves successfully |
| 2 | Member B | Profile → **Risk Alerts** ON | — |
| 3 | Member B | Background app | Push + inbox entry for low score |
| 4 | Member B | Turn **Risk Alerts** OFF, repeat check-in from A | No new alert for B |

## Smoke test D — Transport + rules

| Step | Action | Expected |
|------|--------|----------|
| 1 | Upload profile photo in **Profile** | Photo appears (Storage rules deployed) |
| 2 | Request ride with covered ZIP | Green coverage banner |
| 3 | Request ride with uncovered ZIP | Orange banner; Uber/Lyft still shown |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| No push, inbox works | iOS: APNs key in Firebase; use physical device |
| Permission denied on `config/` | Redeploy `firestore.rules` |
| Functions errors | Firebase Console → Functions → Logs |
| No FCM token | Sign out/in; check `users/{uid}/fcm_tokens` in Firestore |
| Deploy failed “Blaze plan” | Upgrade billing at Firebase Console |

## Seed transport coverage (if not run yet)

```bash
cd /Users/ericfu/StudioProjects/care_signal
node scripts/seed-transport-coverage.js
```

Requires Application Default Credentials:

```bash
gcloud auth application-default login --project care-signal-ai
```
