#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  migrate_one_stack.sh --stack <stack_dir> [--new-root <dir>] [--old-root <dir>] [--dry] [--restart]

Inputs:
  --stack <dir>      Folder containing a compose file:
                     compose.yml|compose.yaml|docker-compose.yml|docker-compose.yaml
  --new-root <dir>   Target root for migrated appdata (default: /srv/appdata)
  --old-root <dir>   Source root to migrate FROM if .env lacks DOCKER_VOLUME_STORAGE
                     Example: /mnt/nas/DockerServices
  --dry              Print actions only; do not copy or edit files
  --restart          Run: docker compose down && docker compose up -d after migration

Old root resolution:
  1) If <stack_dir>/.env exists and sets DOCKER_VOLUME_STORAGE, use that
  2) Else require --old-root

What it migrates:
  Only bind paths that start with:
    ${DOCKER_VOLUME_STORAGE}/...
  and rewrites those to:
    <new-root>/...

Examples:
  # stack has .env with DOCKER_VOLUME_STORAGE
  ./migrate_one_stack.sh --stack /path/to/forgejo --dry

  # stack has no .env (or no DOCKER_VOLUME_STORAGE)
  ./migrate_one_stack.sh --stack /path/to/forgejo --old-root /mnt/nas/DockerServices --new-root /srv/appdata --restart
EOF
}

DRY=0
RESTART=0
STACK_DIR=""
NEW_ROOT="/srv/appdata"
OLD_ROOT_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry) DRY=1; shift;;
    --restart) RESTART=1; shift;;
    --stack) STACK_DIR="${2:-}"; shift 2;;
    --new-root) NEW_ROOT="${2:-}"; shift 2;;
    --old-root) OLD_ROOT_ARG="${2:-}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

[[ -n "$STACK_DIR" ]] || { echo "ERROR: --stack is required"; usage; exit 2; }
[[ -d "$STACK_DIR" ]] || { echo "ERROR: --stack not found: $STACK_DIR"; exit 2; }

COMPOSE_CANDIDATES=("compose.yml" "compose.yaml" "docker-compose.yml" "docker-compose.yaml")

log(){ echo -e "\n==> $*"; }

find_compose_file() {
  local dir="$1"
  for f in "${COMPOSE_CANDIDATES[@]}"; do
    [[ -f "$dir/$f" ]] && { echo "$dir/$f"; return 0; }
  done
  return 1
}

resolve_old_root() {
  local envfile="$STACK_DIR/.env"
  local old_root=""

  if [[ -f "$envfile" ]]; then
    # shellcheck disable=SC1090
    source "$envfile" || true
    old_root="${DOCKER_VOLUME_STORAGE:-}"
  fi

  if [[ -z "$old_root" ]]; then
    old_root="$OLD_ROOT_ARG"
  fi

  if [[ -z "$old_root" ]]; then
    echo "ERROR: Could not determine old root."
    echo " - No DOCKER_VOLUME_STORAGE found in $envfile"
    echo " - And --old-root was not provided"
    exit 2
  fi

  echo "$old_root"
}

extract_binds() {
  local compose_file="$1"
  # host-side bind paths like ${DOCKER_VOLUME_STORAGE}/something (unique)
  grep -oE '\$\{DOCKER_VOLUME_STORAGE\}/[^: ]+' "$compose_file" | sort -u || true
}

copy_path() {
  local src="$1"
  local dst="$2"

  if [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    if [[ "$DRY" == "1" ]]; then
      echo "DRY: cp -a '$src' '$dst'"
    else
      cp -a "$src" "$dst"
    fi
    return 0
  fi

  mkdir -p "$dst"
  if [[ "$DRY" == "1" ]]; then
    echo "DRY: rsync -aHAX --numeric-ids '$src/' '$dst/'"
  else
    rsync -aHAX --numeric-ids --info=progress2 "$src/" "$dst/"
  fi
}

rewrite_compose() {
  local compose_file="$1"
  local backup="$compose_file.bak.$(date +%F_%H%M%S)"

  if [[ "$DRY" == "1" ]]; then
    echo "DRY: would backup to $backup and replace \${DOCKER_VOLUME_STORAGE} -> $NEW_ROOT"
  else
    cp "$compose_file" "$backup"
    sed -i "s#\${DOCKER_VOLUME_STORAGE}#${NEW_ROOT}#g" "$compose_file"
  fi
}

restart_stack() {
  [[ "$RESTART" == "1" ]] || return 0
  if [[ "$DRY" == "1" ]]; then
    echo "DRY: (cd '$STACK_DIR' && docker compose down && docker compose up -d)"
  else
    (cd "$STACK_DIR" && docker compose down && docker compose up -d)
  fi
}

compose_file="$(find_compose_file "$STACK_DIR")" || { echo "ERROR: No compose file found in $STACK_DIR"; exit 2; }
OLD_ROOT="$(resolve_old_root)"

log "Stack dir: $STACK_DIR"
log "Compose: $compose_file"
log "Old root: $OLD_ROOT"
log "New root: $NEW_ROOT"
log "Dry run: $DRY | Restart: $RESTART"

binds="$(extract_binds "$compose_file")"
if [[ -z "$binds" ]]; then
  echo "Nothing to migrate: no \${DOCKER_VOLUME_STORAGE} binds found in compose."
  echo "TIP: This script only migrates binds that use \${DOCKER_VOLUME_STORAGE}."
  exit 0
fi

log "Paths to migrate:"
echo "$binds" | sed 's/^/ - /'

while IFS= read -r bind; do
  rel="${bind#\$\{DOCKER_VOLUME_STORAGE\}/}"
  src="$OLD_ROOT/$rel"
  dst="$NEW_ROOT/$rel"

  if [[ ! -e "$src" ]]; then
    echo "WARN missing source: $src"
    continue
  fi

  copy_path "$src" "$dst"
done <<< "$binds"

rewrite_compose "$compose_file"
restart_stack

log "Done."
echo "NOTE: This does NOT fix container-internal mount targets (e.g., Postgres should mount to /var/lib/postgresql/data). Review DB mounts manually."