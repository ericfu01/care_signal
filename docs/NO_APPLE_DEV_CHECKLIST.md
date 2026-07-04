# Testing without Apple Developer ($99/yr)

Use this checklist while you defer APNs / TestFlight. **In-app Notifications** replaces lock-screen push for most tests.

## Backend status (should already be done)

- [x] Blaze plan enabled
- [x] Cloud Functions deployed (notifications, account deletion, peer groups)
- [x] Firestore rules + indexes deployed
- [ ] Transport coverage seeded → run:
  ```bash
  ./scripts/seed-transport-coverage-http.sh
  ```
  Or create `config/transport_coverage` manually in [Firestore Console](https://console.firebase.google.com/project/care-signal-ai/firestore).

## Run the app

```bash
cd /Users/ericfu/StudioProjects/care_signal
flutter run
```

Simulator or your own iPhone via Xcode (free Apple ID) both work.

---

## Checklist (work through in order)

### 1. Daily check-in & trends
- [ ] Menu → **Daily Check-in** → complete with any score
- [ ] **Home** shows updated wellness metrics
- [ ] **Trends** tab shows chart (after a few check-ins)
- [ ] **Insights** tab loads (AI copy optional without OpenAI key)

### 2. Profile & privacy
- [ ] Upload **profile photo** on Home avatar → “Profile photo saved.”
- [ ] **Profile** → toggle **Share Trends**, **Risk Alerts**, **Share with Partners**
- [ ] Force-quit app, reopen → photo and toggles persist

### 3. Transport coverage
- [ ] Menu → **Volunteers** → **Transportation**
- [ ] ZIP `94102` → green “San Francisco Bay Area” banner
- [ ] ZIP `90210` → orange “No volunteer drivers near…” banner

### 4. Family messages (in-app)
Needs **two accounts in the same family** (two simulators, or phone + simulator).

- [ ] User B: **Family messages** → send DM to User A
- [ ] User A: open **Notifications** (bell) → new family message row
- [ ] Tap row → opens chat with B  
  *(No lock-screen push until APNs is set up — keep app open or check inbox manually.)*

### 5. Volunteer request lifecycle (in-app)
- [ ] Family: **Volunteers** → request **Respite** or **Transportation**
- [ ] Volunteer account: **Notifications** → new request row
- [ ] Volunteer: tap → **Accept** or **Propose counter time**
- [ ] Family: **Notifications** → update row → tap opens request detail

### 6. Risk alert (in-app)
- [ ] Member A: **Daily Check-in** with score **below 55**
- [ ] Member B: **Profile** → **Risk Alerts** ON
- [ ] Member B: **Notifications** → wellness alert row
- [ ] Member B: turn **Risk Alerts** OFF → repeat A’s check-in → B should **not** get a new alert

### 7. Family profile photos
- [ ] Member A uploads photo
- [ ] Member B (same family) sees A’s avatar on Home / family list

### 8. Debug notification (debug builds only)
- [ ] **Notifications** → flask icon or **Send test notification**
- [ ] Row appears in inbox

### 9. Peer group invitation (in-app)
Needs a **family account** invited by a **volunteer host** (email must match an existing account).

- [ ] Host: Peer Groups tab → manage group → invite family email
- [ ] Invitee (signed in with that email): **Notifications** → peer group invitation
- [ ] Tap → opens **Peer Groups** → **Accept invitation**

### 10. Account deletion (destructive — use a test account)
- [ ] **Profile** → **Delete Account** → confirm
- [ ] Returned to sign-in screen; same credentials no longer work

### 11. Staff / partner (optional)
- [ ] Firestore: set your test user's `accountType` to `staff` for the first admin (bootstrap only)
- [ ] Staff app → **Team** tab → create code for a teammate
- [ ] Teammate signs in → **Staff access code** → enters code → staff dashboard loads
- [ ] Set `accountType` to `partner` (or sign up as Care partner) → partner insights loads

---

## App config (Firestore)

Set support email without an app update:

1. Firestore → `config/app`
2. Fields:
   - `supportEmail` — shown on Help page
   - `inviteHelpUrl` — optional link in invite emails

See [`docs/EMAIL_SETUP.md`](EMAIL_SETUP.md) for SendGrid setup (peer group + staff invite emails).

---

## What you cannot test yet (needs Apple Developer)

| Feature | Workaround |
|---------|------------|
| Push banner when app is backgrounded/closed (iOS) | Use **Notifications** inbox with app open |
| TestFlight / App Store | Xcode install only |

**Android phone:** FCM push can work without Apple Developer — use a second Android device for real push tests.

---

## Verify backend (optional)

| Check | Where |
|-------|--------|
| Functions live | [Firebase Functions](https://console.firebase.google.com/project/care-signal-ai/functions) |
| Transport config | Firestore → `config/transport_coverage` |
| Inbox writes | Firestore → `users/{uid}/notifications` after tests |
| FCM tokens | Firestore → `users/{uid}/fcm_tokens` (after sign-in) |

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Empty Notifications | Cloud Functions deployed? Check [Function logs](https://console.firebase.google.com/project/care-signal-ai/functions/logs) |
| No volunteer alerts | Volunteer account must have `accountType: volunteer` and matching lane |
| Transport always Bay Area default | Run `./scripts/seed-transport-coverage-http.sh` |
| Photo upload fails | Storage rules deployed; full app restart after plist changes |

---

## When you get Apple Developer

1. Follow [`docs/IOS_PUSH_SETUP.md`](IOS_PUSH_SETUP.md)
2. Re-run push sections in [`docs/P0_DEVICE_SMOKE_TEST.md`](P0_DEVICE_SMOKE_TEST.md)
