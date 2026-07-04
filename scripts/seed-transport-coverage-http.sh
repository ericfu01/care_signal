#!/usr/bin/env bash
# Seeds config/transport_coverage via the seedTransportCoverage HTTP function.
set -euo pipefail

PROJECT="${FIREBASE_PROJECT_ID:-care-signal-ai}"
SECRET="${SEED_SECRET:-care-signal-bootstrap}"
URL="https://us-central1-${PROJECT}.cloudfunctions.net/seedTransportCoverage?secret=${SECRET}"

echo "Seeding transport coverage via ${URL}"
curl -fsS "$URL" | python3 -m json.tool 2>/dev/null || curl -fsS "$URL"
echo ""
echo "Done. Verify in Firestore: config/transport_coverage"
