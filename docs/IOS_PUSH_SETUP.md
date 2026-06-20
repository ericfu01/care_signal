# iOS push notifications — Care Signal

Bundle ID: **`com.ericfu.careSignal`**  
Firebase project: **`care-signal-ai`**

Remote push **does not work on the iOS Simulator**. Use a **physical iPhone** and complete every step below.

---

## 1. Apple Developer — APNs key (one time)

1. Go to [Apple Developer → Keys](https://developer.apple.com/account/resources/authkeys/list).
2. **+** → name it e.g. `Care Signal APNs`.
3. Enable **Apple Push Notifications service (APNs)** → Continue → Register.
4. **Download** the `.p8` file (only once). Note:
   - **Key ID**
   - **Team ID** (Membership details page)

Keep the `.p8` file private.

---

## 2. Firebase — upload APNs key

1. [Firebase Console](https://console.firebase.google.com) → **care-signal-ai**.
2. **Project settings** (gear) → **Cloud Messaging** tab.
3. Under **Apple app configuration**, select the iOS app (`com.ericfu.careSignal`).
4. **Upload** the APNs Authentication Key:
   - `.p8` file  
   - Key ID  
   - Team ID  
5. Save.

Without this step, FCM tokens are saved but **no push is delivered**.

---

## 3. Xcode — signing & capabilities

1. Open **`ios/Runner.xcworkspace`** (not `.xcodeproj`).
2. Select **Runner** target → **Signing & Capabilities**.
3. Choose your **Team** and ensure **Automatically manage signing** is on.
4. Confirm capabilities (entitlements files in the repo should enable these):
   - **Push Notifications**
   - **Background Modes** → **Remote notifications**

If Push Notifications is missing, click **+ Capability** and add it.

5. Build to a **real device** (not Simulator): **Product → Run**.

---

## 4. App permissions

On first launch after sign-in, accept **Allow Notifications** when iOS asks.

If you denied it: **Settings → Care Signal → Notifications → Allow Notifications**.

---

## 5. Deploy backend

```bash
cd functions && npm install && cd ..
firebase deploy --only firestore:rules,functions:notifyFamilyMessage --project care-signal-ai
```

---

## 6. Verify token on device

1. `flutter run` on your **iPhone** (debug).
2. Sign in → check Xcode **console** for:
   - `[CareSignal][Notifications] APNs token: ...` (not null)
   - `[CareSignal][Notifications] FCM token: ...`
3. In Firestore: `users/{your_uid}/fcm_tokens` should have a document with a `token` field.

**Debug:** Notifications screen → flask icon → **Copy FCM token** (if shown) for Firebase test messages.

---

## 7. Send a real test push (one phone)

### Option A — Firebase Console

1. Cloud Messaging → **Send test message**.
2. Paste **FCM token** from step 6.
3. Add custom data (optional, for tap-to-chat):

   | Key | Example |
   |-----|---------|
   | `type` | `family_message` |
   | `familyId` | your family id |
   | `chatId` | `uidA_uidB` |
   | `otherUid` | sender uid |
   | `otherDisplayName` | `Eric` |

### Option B — Family DM

Use a second account (another phone, Android emulator, or sign out/in). Background the app on the recipient iPhone, send a DM from the other account.

---

## Troubleshooting

| Symptom | Fix |
|--------|-----|
| `APNs token: null` | Physical device only; Push capability + entitlements; reinstall app |
| Token in Firestore, no push | Upload `.p8` in Firebase; deploy Cloud Function |
| Push in debug, not TestFlight | Release build uses **production** APNs (`RunnerRelease.entitlements`); same `.p8` key works for both |
| Permission denied on `fcm_tokens` | `firebase deploy --only firestore:rules` |
| No alert when app open | Normal on Android; iOS should show banner if presentation options are set (already in app) |

### `aps-environment` mismatch

| How you run | Entitlements file | APNs environment |
|-------------|-------------------|------------------|
| `flutter run` (debug) | `Runner.entitlements` | development |
| `flutter run --release` / TestFlight / App Store | `RunnerRelease.entitlements` | production |

Firebase **APNs Auth Key (.p8)** supports both environments.

---

## Checklist

- [ ] APNs `.p8` uploaded to Firebase for `com.ericfu.careSignal`
- [ ] Xcode: Push + Background Remote notifications
- [ ] Physical iPhone, notifications allowed
- [ ] `fcm_tokens` doc exists after sign-in
- [ ] Cloud Function `notifyFamilyMessage` deployed
- [ ] Test message received (Console or family DM)
