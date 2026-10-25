#!/usr/bin/env bash
# Unattended maintenance for the Raspberry Pi:
#   1. apt-get update + download updates
#   2. apply OS updates
#   3. pull updated docker images (and recreate changed containers)
# All output is written to /var/log/pi-maintenance.log and pushed to Loki,
# which is queryable from Grafana (job="pi-maintenance").

set -uo pipefail

LOKI_URL="${LOKI_URL:-http://127.0.0.1:3100}"
STACKS_DIR="${STACKS_DIR:-/opt/stacks}"
LOG_FILE="${LOG_FILE:-/var/log/pi-maintenance.log}"
LOCK_FILE="${LOCK_FILE:-/run/lock/pi-maintenance.lock}"
RECREATE_CONTAINERS="${RECREATE_CONTAINERS:-true}"   # run 'up -d' after pulling
PRUNE_IMAGES="${PRUNE_IMAGES:-true}"                 # remove dangling images afterwards
AUTO_REBOOT="${AUTO_REBOOT:-false}"                  # reboot after updates if one is required
REBOOT_DELAY_MINUTES="${REBOOT_DELAY_MINUTES:-2}"    # delay before the scheduled reboot
FORCE_REBOOT="${FORCE_REBOOT:-false}"                # reboot at the end of the script regardless of if one is required
HOST_NAME="$(hostname)"
FAILURES=0

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)." >&2
  exit 1
fi

# Prevent overlapping runs
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Another maintenance run is in progress; exiting." >&2
  exit 1
fi

touch "$LOG_FILE" && chmod 640 "$LOG_FILE"

# ship <level> <step>: read lines on stdin and push them to Loki as one batch.
ship() {
  local level="$1" step="$2" values payload
  values=$(tr -d '\000-\010\013-\037' | grep -v '^[[:space:]]*$' | tail -n 2000 |
    awk -v base="$(date +%s)" '{
      gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t");
      printf "%s[\"%d%09d\",\"%s\"]", (NR>1 ? "," : ""), base, NR, $0
    }')
  [[ -z "$values" ]] && return 0
  payload="{\"streams\":[{\"stream\":{\"job\":\"pi-maintenance\",\"host\":\"${HOST_NAME}\",\"level\":\"${level}\",\"step\":\"${step}\"},\"values\":[${values}]}]}"
  curl -sS -m 15 -o /dev/null --fail -X POST -H 'Content-Type: application/json' \
    --data-binary "$payload" "${LOKI_URL}/loki/api/v1/push" 2>>"$LOG_FILE" ||
    echo "$(date -Is) [warn] could not push logs to Loki at ${LOKI_URL}" >>"$LOG_FILE"
}

log() {
  local level="$1"; shift
  printf '%s [%s] %s\n' "$(date -Is)" "$level" "$*" | tee -a "$LOG_FILE"
  printf '%s\n' "$*" | ship "$level" main
}

# run_step <name> <command...>: run a command, log its output locally and to Loki.
run_step() {
  local name="$1"; shift
  local out rc
  out=$(mktemp)
  log info "START ${name}"
  "$@" >"$out" 2>&1
  rc=$?
  tee -a "$LOG_FILE" <"$out" >/dev/null
  ship "$([[ $rc -eq 0 ]] && echo info || echo error)" "$name" <"$out"
  rm -f "$out"
  if [[ $rc -eq 0 ]]; then
    log info "OK ${name}"
  else
    log error "FAILED ${name} (exit ${rc})"
    FAILURES=$((FAILURES + 1))
  fi
  return $rc
}

export DEBIAN_FRONTEND=noninteractive
APT_OPTS=(-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

log info "Maintenance run started on ${HOST_NAME}"

# --- OS updates -------------------------------------------------------------
run_step apt-update       apt-get update
run_step apt-download     apt-get "${APT_OPTS[@]}" --download-only upgrade
run_step apt-upgrade      apt-get "${APT_OPTS[@]}" upgrade
run_step apt-autoremove   apt-get "${APT_OPTS[@]}" autoremove --purge

# --- Docker images ----------------------------------------------------------
if command -v docker >/dev/null 2>&1; then
  shopt -s nullglob
  for dir in "${STACKS_DIR}"/*/; do
    dir="${dir%/}"
    name="$(basename "$dir")"
    compose_file=""
    for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
      [[ -f "$dir/$f" ]] && { compose_file="$dir/$f"; break; }
    done
    [[ -z "$compose_file" ]] && continue

    run_step "docker-pull-${name}" docker compose --project-directory "$dir" -f "$compose_file" pull
    if [[ "$RECREATE_CONTAINERS" == "true" ]]; then
      run_step "docker-up-${name}" docker compose --project-directory "$dir" -f "$compose_file" up -d --remove-orphans
    fi
  done
  if [[ "$PRUNE_IMAGES" == "true" ]]; then
    run_step docker-image-prune docker image prune -f
  fi
else
  log warning "docker not found; skipping image updates"
fi

reboot_required=false
[[ -f /var/run/reboot-required ]] && reboot_required=true

if [[ "$FORCE_REBOOT" == "true" ]]; then
  log warning "Forcing reboot; scheduling reboot in ${REBOOT_DELAY_MINUTES} minute(s)."
  run_step force-reboot shutdown -r +"${REBOOT_DELAY_MINUTES}" "Scheduled by pi-maintenance"
elif [[ "$reboot_required" == "true" && "$AUTO_REBOOT" == "true" && $FAILURES -eq 0 ]]; then
  log warning "Reboot required; scheduling reboot in ${REBOOT_DELAY_MINUTES} minute(s)."
  shutdown -r +"${REBOOT_DELAY_MINUTES}" "Scheduled by pi-maintenance after updates"
elif [[ "$reboot_required" == "true" ]]; then
  log warning "A reboot is required to finish applying updates (not rebooting automatically)."
fi

if [[ $FAILURES -eq 0 ]]; then
  log info "Maintenance run finished successfully"
  exit 0
else
  log error "Maintenance run finished with ${FAILURES} failed step(s)"
  exit 1
fi
