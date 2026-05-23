#!/usr/bin/env bash
set -euo pipefail

IMAGE="${LIBRETV_IMAGE:-ghcr.io/kuaileshangwei/libretv:latest}"
INSTALL_DIR="${LIBRETV_INSTALL_DIR:-$HOME/libretv}"
PORT="${PORT:-8899}"
PASSWORD="${PASSWORD:-}"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required. Install Docker first, then rerun this script."
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "Docker Compose is required."
  exit 1
fi

if [ -z "$PASSWORD" ]; then
  read -r -s -p "Set LibreTV PASSWORD: " PASSWORD
  echo
fi

if [ -z "$PASSWORD" ]; then
  echo "PASSWORD cannot be empty."
  exit 1
fi

mkdir -p "$INSTALL_DIR"

if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
  cp "$INSTALL_DIR/docker-compose.yml" "$INSTALL_DIR/docker-compose.yml.bak"
fi

cat > "$INSTALL_DIR/docker-compose.yml" <<YAML
services:
  libretv:
    image: ${IMAGE}
    container_name: libretv
    ports:
      - "${PORT}:8080"
    environment:
      - PASSWORD=${PASSWORD}
    restart: unless-stopped
YAML

cd "$INSTALL_DIR"
"${COMPOSE_CMD[@]}" pull
"${COMPOSE_CMD[@]}" up -d

echo "LibreTV is running at http://localhost:${PORT}"
