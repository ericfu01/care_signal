# Outbound email (peer group invites)

Care Signal sends optional invitation emails through **SendGrid** when Cloud Functions secrets are configured.

## Setup

1. Create a [SendGrid](https://sendgrid.com) account and verify a sender address (or domain).
2. Create an API key with **Mail Send** permission.
3. Store secrets in Firebase (replace values):

```bash
firebase functions:secrets:set SENDGRID_API_KEY --project care-signal-ai
firebase functions:secrets:set EMAIL_FROM --project care-signal-ai
```

`EMAIL_FROM` must be a verified sender in SendGrid (e.g. `support@yourdomain.com`).

4. Redeploy functions that send mail:

```bash
./scripts/deploy-cloud-functions.sh
```

## Behavior

| Event | Email | In-app |
|-------|-------|--------|
| Family peer group invite | Sent to invitee email (always, if configured) | If account exists |
| Co-host invite | Sent to volunteer email (if configured) | Always |

If secrets are missing, invites still work in-app; email is skipped with a log line in Cloud Functions.

## Optional Firestore config

`config/app` fields:

| Field | Purpose |
|-------|---------|
| `supportEmail` | Shown on Help page |
| `inviteHelpUrl` | Link appended to invite emails |

Example:

```json
{
  "supportEmail": "support@yourdomain.com",
  "inviteHelpUrl": "https://yourdomain.com/care-signal"
}
```
