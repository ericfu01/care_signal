#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Deploying Firestore rules to care-signal-ai..."
firebase deploy --only firestore:rules --project care-signal-ai

echo ""
echo "Firestore rules deployed."
echo ""
echo "Storage rules were NOT deployed. Enable Storage first:"
echo "  https://console.firebase.google.com/project/care-signal-ai/storage"
echo "Then run:"
echo "  firebase deploy --only storage --project care-signal-ai"
