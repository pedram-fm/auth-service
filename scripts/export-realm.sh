#!/bin/bash

# ===========================================
# Auth Service — Export Realm
# ===========================================
# Usage: ./scripts/export-realm.sh <realm-name>
# Exports a specific realm configuration to keycloak/realms/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="${PROJECT_DIR}/docker"

# Load env
if [ -f "${DOCKER_DIR}/.env" ]; then
    export $(grep -v '^#' "${DOCKER_DIR}/.env" | xargs)
fi

REALM_NAME="${1:-}"

if [ -z "$REALM_NAME" ]; then
    echo "Usage: $0 <realm-name>"
    echo ""
    echo "Available realms:"
    docker exec auth_keycloak /opt/keycloak/bin/kcadm.sh get realms \
        --server http://localhost:8080 \
        --realm master \
        --user "${KEYCLOAK_ADMIN:-admin}" \
        --password "${KEYCLOAK_ADMIN_PASSWORD:-admin}" \
        --fields realm 2>/dev/null | grep -oP '"realm"\s*:\s*"\K[^"]+' | grep -v "master" || echo "  (none found or Keycloak not running)"
    exit 1
fi

OUTPUT_FILE="${PROJECT_DIR}/keycloak/realms/${REALM_NAME}.json"

echo "=== Exporting Realm: ${REALM_NAME} ==="

docker exec auth_keycloak /opt/keycloak/bin/kcadm.sh get "realms/${REALM_NAME}" \
    --server http://localhost:8080 \
    --realm master \
    --user "${KEYCLOAK_ADMIN:-admin}" \
    --password "${KEYCLOAK_ADMIN_PASSWORD:-admin}" \
    > "${OUTPUT_FILE}" 2>/dev/null

echo "Exported to: ${OUTPUT_FILE}"
echo "Done."
