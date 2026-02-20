#!/bin/bash

# ===========================================
# Auth Service — Health Check
# ===========================================
# Usage: ./scripts/health-check.sh
# Checks the health of all services

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(dirname "$SCRIPT_DIR")/docker"

# Load env
if [ -f "${DOCKER_DIR}/.env" ]; then
    export $(grep -v '^#' "${DOCKER_DIR}/.env" | xargs)
fi

KC_PORT="${KC_HTTP_PORT:-8080}"
NGINX_PORT="${NGINX_HTTP_PORT:-80}"

echo "=== Auth Service Health Check ==="
echo ""

# --- Docker Containers ---
echo ">>> Container Status:"
docker ps --filter "name=auth_" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "  Docker not available"
echo ""

# --- PostgreSQL ---
echo ">>> PostgreSQL:"
if docker exec auth_postgres pg_isready -U "${POSTGRES_USER:-keycloak}" -d "${POSTGRES_DB:-keycloak}" &>/dev/null; then
    echo "  ✓ PostgreSQL is ready"
else
    echo "  ✗ PostgreSQL is NOT ready"
fi
echo ""

# --- Keycloak ---
echo ">>> Keycloak:"
KC_HEALTH=$(curl -sf "http://localhost:${KC_PORT}/health/ready" 2>/dev/null || echo "FAIL")
if echo "$KC_HEALTH" | grep -q '"status".*"UP"'; then
    echo "  ✓ Keycloak is ready"
else
    echo "  ✗ Keycloak is NOT ready"
    echo "  Response: ${KC_HEALTH}"
fi
echo ""

# --- Nginx ---
echo ">>> Nginx:"
if docker exec auth_nginx nginx -t &>/dev/null; then
    echo "  ✓ Nginx config is valid"
else
    echo "  ✗ Nginx config has errors"
fi

NGINX_RESPONSE=$(curl -sf -o /dev/null -w "%{http_code}" "http://localhost:${NGINX_PORT}" 2>/dev/null || echo "000")
if [ "$NGINX_RESPONSE" != "000" ]; then
    echo "  ✓ Nginx is responding (HTTP ${NGINX_RESPONSE})"
else
    echo "  ✗ Nginx is NOT responding"
fi
echo ""

echo "=== Done ==="
