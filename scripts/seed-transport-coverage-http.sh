#!/usr/bin/env bash
# Seeds config/transport_coverage via the seedTransportCoverage HTTP function.
# Prefer scripts/seed-transport-coverage.js (Admin SDK) when possible.
set -euo pipefail

PROJECT="${FIREBASE_PROJECT_ID:-care-signal-ai}"

if [[ -z "${SEED_SECRET:-}" ]]; then
  echo "Set SEED_SECRET to match the Cloud Function env var, then retry."
  echo "Or seed with Admin SDK: node scripts/seed-transport-coverage.js"
  exit 1
fi

URL="https://us-central1-${PROJECT}.cloudfunctions.net/seedTransportCoverage?secret=${SEED_SECRET}"

echo "Seeding transport coverage via ${URL}"
curl -fsS "$URL" | python3 -m json.tool 2>/dev/null || curl -fsS "$URL"
echo ""
echo "Done. Verify in Firestore: config/transport_coverage"
