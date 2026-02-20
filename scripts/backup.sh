#!/bin/bash

# ===========================================
# Auth Service — Backup Script
# ===========================================
# Usage: ./scripts/backup.sh
# Creates a backup of:
#   - PostgreSQL database
#   - Keycloak realm exports

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups/$(date +%Y-%m-%d_%H-%M-%S)"
DOCKER_DIR="${PROJECT_DIR}/docker"

# Load env
if [ -f "${DOCKER_DIR}/.env" ]; then
    export $(grep -v '^#' "${DOCKER_DIR}/.env" | xargs)
fi

echo "=== Auth Service Backup ==="
echo "Backup directory: ${BACKUP_DIR}"

mkdir -p "${BACKUP_DIR}"

# --- PostgreSQL Backup ---
echo ""
echo ">>> Backing up PostgreSQL..."
docker exec auth_postgres pg_dump \
    -U "${POSTGRES_USER:-keycloak}" \
    -d "${POSTGRES_DB:-keycloak}" \
    --format=custom \
    --file=/tmp/keycloak_backup.dump

docker cp auth_postgres:/tmp/keycloak_backup.dump "${BACKUP_DIR}/keycloak_db.dump"
docker exec auth_postgres rm /tmp/keycloak_backup.dump

echo "    PostgreSQL backup: ${BACKUP_DIR}/keycloak_db.dump"

# --- Realm Export ---
echo ""
echo ">>> Exporting realms..."
# Note: Keycloak 26+ supports partial export via admin API
# This exports all realms excluding master
REALMS=$(docker exec auth_keycloak /opt/keycloak/bin/kcadm.sh get realms \
    --server http://localhost:8080 \
    --realm master \
    --user "${KEYCLOAK_ADMIN:-admin}" \
    --password "${KEYCLOAK_ADMIN_PASSWORD:-admin}" \
    --fields realm 2>/dev/null | grep -oP '"realm"\s*:\s*"\K[^"]+' | grep -v "master" || true)

mkdir -p "${BACKUP_DIR}/realms"

for realm in $REALMS; do
    echo "    Exporting realm: ${realm}"
    docker exec auth_keycloak /opt/keycloak/bin/kcadm.sh get "realms/${realm}" \
        --server http://localhost:8080 \
        --realm master \
        --user "${KEYCLOAK_ADMIN:-admin}" \
        --password "${KEYCLOAK_ADMIN_PASSWORD:-admin}" \
        > "${BACKUP_DIR}/realms/${realm}.json" 2>/dev/null || echo "    Warning: Could not export ${realm}"
done

# --- Summary ---
echo ""
echo "=== Backup Complete ==="
echo "Location: ${BACKUP_DIR}"
ls -lh "${BACKUP_DIR}"
echo ""
echo "To restore database:"
echo "  docker exec -i auth_postgres pg_restore -U keycloak -d keycloak < ${BACKUP_DIR}/keycloak_db.dump"
