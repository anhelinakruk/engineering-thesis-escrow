#!/usr/bin/env bash
# Starts everything the app needs on this Mac: the Podman VM, SurrealDB with
# the schema, and the Rust backend (in the foreground; Ctrl+C stops it).
# The chain itself is Sepolia (or Anvil), configured in .env and Config.swift.
set -euo pipefail
cd "$(dirname "$0")"

set -a; source .env; set +a

podman machine start 2>/dev/null || true   # "already running" is fine
podman compose up -d

echo "Waiting for SurrealDB..."
until curl -sf "http://${SURREALDB_ADDRESS}/health" >/dev/null; do sleep 1; done

# Re-importing is harmless: definitions that already exist are reported as
# errors by SurrealDB and skipped, everything else is created.
curl -s -X POST -u "${SURREAL_USER}:${SURREAL_PASS}" \
  -H "surreal-ns: ${SURREALDB_NAMESPACE}" -H "surreal-db: ${SURREALDB_DATABASE}" \
  --data-binary @fixtures/setup.surql "http://${SURREALDB_ADDRESS}/import" >/dev/null

echo "Starting backend on :3000..."
cd server && exec cargo run
