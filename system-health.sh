#!/usr/bin/env bash
set -u

ENV_FILE="${ENV_FILE:-/etc/homelab-monitoring/system-push.env}"
# shellcheck disable=SC1090
source "$ENV_FILE"

REQUIRED_UNITS=(docker.service tailscaled.service)
REQUIRED_MOUNTS=(/mnt/data /mnt/backup)
MAX_DISK_PERCENT="${MAX_DISK_PERCENT:-90}"

send_result() {
  local status="$1" message="$2"
  curl --silent --show-error --fail --get \
    --data-urlencode "status=$status" \
    --data-urlencode "msg=$message" \
    "$PUSH_URL" >/dev/null
}

problems=()

for unit in "${REQUIRED_UNITS[@]}"; do
  systemctl is-active --quiet "$unit" || problems+=("$unit inactive")
done

for mount in "${REQUIRED_MOUNTS[@]}"; do
  mountpoint -q "$mount" || problems+=("$mount not mounted")
done

while read -r filesystem pct mountpoint_name; do
  used="${pct%%%}"
  [[ "$used" =~ ^[0-9]+$ ]] || continue
  (( used < MAX_DISK_PERCENT )) || problems+=("$mountpoint_name ${used}% full")
done < <(df -P --output=source,pcent,target | tail -n +2)

if ((${#problems[@]})); then
  msg="Unhealthy: $(IFS='; '; echo "${problems[*]}")"
  send_result down "$msg" || true
  logger -t system-health "$msg"
  exit 1
fi

msg="Healthy: required services, mounts, and disk thresholds operational"
send_result up "$msg"
logger -t system-health "$msg"
