#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Installing function dependencies..."
(cd functions && npm install)

echo "Deploying Care Signal Cloud Functions to care-signal-ai..."
firebase deploy \
  --only functions:notifyFamilyMessage,functions:notifyVolunteerNewRequest,functions:notifyVolunteerRequestReopened,functions:notifyVolunteerRequestCancelled,functions:syncVolunteerAvailabilityOnRequestChange,functions:notifyFamilyVolunteerRequestUpdate,functions:notifyFamilyRiskAlert \
  --project care-signal-ai

echo "Done."
