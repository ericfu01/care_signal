# Push notifications (Care Signal)

## What’s implemented

- **FCM token registration** — saved to `users/{uid}/fcm_tokens/{id}` when signed in.
- **In-app inbox** — `users/{uid}/notifications` (Notifications screen + unread badge on Home / Volunteer home).
- **Family message pushes** — Cloud Function `notifyFamilyMessage` on new DM; skips FCM if recipient was active in the last 3 minutes (still writes in-app notification).
- **Volunteer new request pushes** — `notifyVolunteerNewRequest` on new pending requests; urgent broadcasts to all volunteers in the lane, normal notifies the matched volunteer (or whole lane if unassigned).
- **Volunteer cancel alerts** — `notifyVolunteerRequestCancelled` when a family cancels a request.
- **Family volunteer updates** — `notifyFamilyVolunteerRequestUpdate` when a volunteer accepts, proposes a counter time, or completes a visit.
- **Risk alerts** — `notifyFamilyRiskAlert` when a family member submits a check-in score below 55; respects each recipient's `riskAlertsEnabled` toggle.
- **Counter declined → pending** — `notifyVolunteerRequestReopened` re-notifies volunteers.
- **Instant volunteer calendar blocks** — `syncVolunteerAvailabilityOnRequestChange` on accept / cancel / complete.
- **Tap to open** — family messages open chat; volunteer alerts open the request; family volunteer updates open the specific request.

## One-time setup

### 1. Firebase Blaze plan

Cloud Functions require the **Blaze (pay-as-you-go)** plan:

1. Open [Firebase usage](https://console.firebase.google.com/project/care-signal-ai/usage/details)
2. Upgrade the project if prompted
3. The free tier still covers modest usage; you only pay for overages

### 2. iOS — APNs in Firebase

**Full checklist:** [docs/IOS_PUSH_SETUP.md](IOS_PUSH_SETUP.md)

1. Create an **APNs Auth Key (.p8)** in Apple Developer and upload it to Firebase (**care-signal-ai** → Project settings → Cloud Messaging → iOS app).
2. Open `ios/Runner.xcworkspace` → Runner → **Signing & Capabilities** → **Push Notifications** + **Background Modes** → Remote notifications (entitlements are in the repo).
3. Run on a **physical iPhone** — Simulator cannot receive remote push.

### 3. Deploy Cloud Functions

From the project root:

```bash
./scripts/deploy-cloud-functions.sh
```

Or manually:

```bash
cd functions && npm install && cd ..
firebase deploy \
  --only functions:notifyFamilyMessage,functions:notifyVolunteerNewRequest,functions:notifyVolunteerRequestReopened,functions:notifyVolunteerRequestCancelled,functions:syncVolunteerAvailabilityOnRequestChange,functions:notifyFamilyVolunteerRequestUpdate,functions:notifyFamilyRiskAlert \
  --project care-signal-ai
```

Also deploy Firestore rules if they changed:

```bash
firebase deploy --only firestore:rules --project care-signal-ai
```

## Test checklist

### Family message push
1. Two physical devices, two family accounts in the same family.
2. Send a DM while the other device is backgrounded.
3. Confirm push + inbox entry on **Notifications**.

### Family volunteer update push
1. Family submits a request; volunteer accepts, proposes a counter time, or marks complete.
2. Family device should get inbox entry + push (unless active in app in last 3 minutes).
3. Tap opens the **specific request** with accept/decline actions when applicable.

### Family volunteer decline push
1. Volunteer declines a pending request.
2. Family gets inbox entry + push with link to the request.

### Risk alert push
1. Family member A submits a daily check-in with score **below 55**.
2. Other family members with **Risk Alerts** enabled get inbox entry + push.
3. Members who turned off Risk Alerts in Profile do not receive the alert.

### Volunteer request deep link
1. Volunteer taps a new/cancelled request notification.
2. App opens the specific request detail screen (falls back to volunteer home if unavailable).

### Volunteer new request push
1. Device A: volunteer signed in (note FCM token under `users/{uid}/fcm_tokens`).
2. Device B: family submits a **normal** or **urgent** volunteer request.
3. Volunteer should get inbox entry + push (unless active in app in last 3 minutes).
4. Urgent requests notify **all volunteers in that lane**.

### Volunteer cancel + calendar block
1. Family cancels an accepted visit → volunteer gets cancel alert; calendar block removed via `syncVolunteerAvailabilityOnRequestChange`.
2. Family accepts counter time → volunteer calendar block appears without reopening the app (after function deploy).

## Troubleshooting

| Issue | Check |
|--------|--------|
| Deploy fails “must be on Blaze plan” | Upgrade Firebase billing (step 1 above) |
| No push, inbox works | APNs/FCM setup; functions deployed; token under `fcm_tokens` |
| No inbox entries | Function logs in Firebase Console → Functions |
| Permission denied on tokens | Deploy latest `firestore.rules` |
| iOS no alert in foreground | Expected on some builds; inbox still updates |

## Single-device debug test

In **debug** builds only, open **Notifications** and tap the flask icon (or **Send test notification** when the list is empty). That adds a test family-message row and shows a banner.

## Next steps (not built yet)

- Daily check-in reminder (local schedule or scheduled function)
- Risk-alert toggles on Profile wired to preferences
- Prune invalid FCM tokens after `sendEachForMulticast` failures
- Deep link volunteer notifications to Requests tab / specific request detail
