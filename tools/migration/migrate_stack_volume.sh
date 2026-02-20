#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  migrate_one_stack.sh --stack <stack_dir> [--new-root <dir>] [--old-root <dir>] [--dry] [--restart]

What it does (single stack):
  1) Finds bind mounts in compose that start with ${DOCKER_VOLUME_STORAGE}/...
  2) Copies data from OLD_ROOT/<rel> -> NEW_ROOT/<rel>
  3) Updates (or creates) <stack_dir>/.env to set:
       DOCKER_VOLUME_STORAGE=<new-root>
  4) Optionally restarts the stack (docker compose down/up)

Inputs:
  --stack <dir>      Folder containing compose.yml|compose.yaml|docker-compose.yml|docker-compose.yaml
  --new-root <dir>   Target root for migrated appdata (default: /srv/appdata)
  --old-root <dir>   Source root to migrate FROM if .env doesn't define DOCKER_VOLUME_STORAGE
  --dry              Print actions only; do not copy or modify files
  --restart          Run: docker compose down && docker compose up -d

Notes:
  - This script DOES NOT edit the compose file.
  - It only migrates binds that use ${DOCKER_VOLUME_STORAGE}.
  - It will create .env if missing so docker compose can resolve the variable.

Examples:
  ./migrate_one_stack.sh --stack /path/to/forgejo --dry
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

# Safe-ish .env read (no sourcing). Supports:
# DOCKER_VOLUME_STORAGE=/path
# DOCKER_VOLUME_STORAGE="/path"
read_env_var() {
  local envfile="$1"
  local key="$2"
  [[ -f "$envfile" ]] || return 1

  # grab last occurrence, strip "key=", strip quotes, strip trailing spaces
  local line
  line="$(grep -E "^[[:space:]]*${key}=" "$envfile" | tail -n 1 || true)"
  [[ -n "$line" ]] || return 1

  local val="${line#*=}"
  # trim whitespace
  val="$(echo "$val" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  # drop surrounding quotes if present
  val="$(echo "$val" | sed -E 's/^"(.*)"$/\1/; s/^\x27(.*)\x27$/\1/')"

  [[ -n "$val" ]] || return 1
  echo "$val"
}

resolve_old_root() {
  local envfile="$STACK_DIR/.env"
  local old_root=""

  old_root="$(read_env_var "$envfile" "DOCKER_VOLUME_STORAGE" || true)"

  if [[ -z "$old_root" ]]; then
    old_root="$OLD_ROOT_ARG"
  fi

  if [[ -z "$old_root" ]]; then
    echo "ERROR: Could not determine old root."
    echo " - No DOCKER_VOLUME_STORAGE in $envfile"
    echo " - And --old-root not provided"
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

update_env_file() {
  local envfile="$STACK_DIR/.env"
  local backup="$envfile.bak.$(date +%F_%H%M%S)"

  if [[ "$DRY" == "1" ]]; then
    if [[ -f "$envfile" ]]; then
      echo "DRY: would backup $envfile -> $backup and set DOCKER_VOLUME_STORAGE=$NEW_ROOT"
    else
      echo "DRY: would create $envfile with DOCKER_VOLUME_STORAGE=$NEW_ROOT"
    fi
    return 0
  fi

  if [[ -f "$envfile" ]]; then
    cp "$envfile" "$backup"
    if grep -qE '^[[:space:]]*DOCKER_VOLUME_STORAGE=' "$envfile"; then
      # replace all occurrences to keep it consistent
      sed -i -E "s#^[[:space:]]*DOCKER_VOLUME_STORAGE=.*#DOCKER_VOLUME_STORAGE=${NEW_ROOT}#g" "$envfile"
    else
      echo "DOCKER_VOLUME_STORAGE=${NEW_ROOT}" >> "$envfile"
    fi
  else
    printf "DOCKER_VOLUME_STORAGE=%s\n" "$NEW_ROOT" > "$envfile"
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
  echo "TIP: If this stack hardcodes /mnt/nas/... in compose, this script won’t touch it."
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

update_env_file
restart_stack

log "Done."