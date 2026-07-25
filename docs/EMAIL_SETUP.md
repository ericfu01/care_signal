# Outbound email (peer group invites)

Care Signal sends optional invitation emails through **SendGrid** when `config/email` is set in Firestore.

## Setup

1. Create a [SendGrid](https://sendgrid.com) account and verify a sender address (or domain).
2. Create an API key with **Mail Send** permission.
3. In [Firestore Console](https://console.firebase.google.com/project/care-signal-ai/firestore), create document **`config/email`**:

```json
{
  "sendgridApiKey": "SG.your-api-key",
  "emailFrom": "support@yourdomain.com"
}
```

`emailFrom` must be a verified sender in SendGrid.

4. Redeploy functions:

```bash
./scripts/deploy-cloud-functions.sh
```

## Behavior

| Event | Email | In-app |
|-------|-------|--------|
| Family peer group invite | Sent to invitee email (if configured) | If account exists |
| Co-host invite | Sent to volunteer email (if configured) | Always |
| Staff invite | Sent when email provided on Team tab | N/A |

If `config/email` is missing, invites still work in-app; email is skipped with a log line in Cloud Functions.

## Optional app config (`config/app`)

| Field | Purpose |
|-------|---------|
| `supportEmail` | Shown on Help page |
| `inviteHelpUrl` | Link appended to invite emails |
| `privacyPolicyUrl` | Optional; opens instead of in-app Privacy Policy |
| `termsOfServiceUrl` | Optional; opens instead of in-app Terms |

Example:

```json
{
  "supportEmail": "support@yourdomain.com",
  "inviteHelpUrl": "https://yourdomain.com/care-signal",
  "privacyPolicyUrl": "https://yourdomain.com/privacy",
  "termsOfServiceUrl": "https://yourdomain.com/terms"
}
```

**Security:** Clients may only read `config/app` and `config/transport_coverage`. `config/email` (SendGrid key) is Admin SDK–only — never put secrets in `config/app`.
