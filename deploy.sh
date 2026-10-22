#!/usr/bin/env bash
#
# Deploy: git pull + pull de imagen + recrear contenedores.
#
# Uso:
#   ./deploy.sh
#   DEPLOY_BRANCH=main ./deploy.sh
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

BRANCH="${DEPLOY_BRANCH:-main}"
COMPOSE_FILE="$ROOT_DIR/filebrowser/docker-compose.yml"
ENV_FILE="$ROOT_DIR/filebrowser/.env"
DATA_DIR="$ROOT_DIR/filebrowser/data"

log() { printf '\n==> %s\n' "$*"; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

log "Deploy (rama $BRANCH)"

[ -d .git ] || fail "$ROOT_DIR no es un repositorio git."
[ -f "$COMPOSE_FILE" ] || fail "No existe $COMPOSE_FILE"
[ -f "$ENV_FILE" ] || fail "No existe $ENV_FILE. Copia filebrowser/.env.example a filebrowser/.env y ajusta los valores."

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  fail "docker compose no está disponible."
fi

# Cargar variables para validar antes de tocar contenedores.
set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

[ -n "${FILES_HOST_PATH:-}" ] || fail "FILES_HOST_PATH está vacío en $ENV_FILE"
[ -d "${FILES_HOST_PATH}" ] || fail "FILES_HOST_PATH no existe o no es un directorio: $FILES_HOST_PATH"

if [ "${FILES_REQUIRE_MOUNT:-false}" = "true" ]; then
  mountpoint -q "$FILES_HOST_PATH" || fail "$FILES_HOST_PATH no está montado. Revisa /etc/fstab y systemctl status mnt-nas_netfiles.mount"
fi

[ -n "${ADMIN_PASSWORD:-}" ] || fail "ADMIN_PASSWORD está vacío en $ENV_FILE"

if [ "$ADMIN_PASSWORD" = "change_me" ]; then
  printf 'Aviso: ADMIN_PASSWORD sigue siendo "change_me". Cámbiala antes de exponer el servicio.\n' >&2
fi

mkdir -p "$DATA_DIR"

if git remote get-url origin >/dev/null 2>&1; then
  log "git pull origin $BRANCH"
  git pull --ff-only origin "$BRANCH"
else
  printf 'Aviso: no hay remoto "origin"; se omite git pull.\n' >&2
fi

log "Validando docker compose"
"${COMPOSE[@]}" -f "$COMPOSE_FILE" --env-file "$ENV_FILE" config >/dev/null

log "Pull de la imagen"
"${COMPOSE[@]}" -f "$COMPOSE_FILE" --env-file "$ENV_FILE" pull

log "Levantando contenedores"
"${COMPOSE[@]}" -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d --remove-orphans --force-recreate

log "Estado"
"${COMPOSE[@]}" -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps

log "Deploy completo."
