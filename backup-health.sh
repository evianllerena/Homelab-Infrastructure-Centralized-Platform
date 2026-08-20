#!/usr/bin/env bash
set -u

ENV_FILE="${ENV_FILE:-/etc/homelab-monitoring/backup-push.env}"
BACKUP_MOUNT="${BACKUP_MOUNT:-/mnt/backup}"
STATUS_FILE="${STATUS_FILE:-$BACKUP_MOUNT/logs/last-success.txt}"
MAX_AGE_SECONDS="${MAX_AGE_SECONDS:-129600}"   # 36 hours
MAX_DISK_PERCENT="${MAX_DISK_PERCENT:-90}"

# shellcheck disable=SC1090
source "$ENV_FILE"

send_result() {
    local status="$1"
    local message="$2"
    curl --silent --show-error --fail --get \
        --data-urlencode "status=$status" \
        --data-urlencode "msg=$message" \
        "$PUSH_URL" >/dev/null
}

fail() {
    send_result "down" "$1" || true
    logger -t backup-health "$1"
    exit 1
}

mountpoint -q "$BACKUP_MOUNT" || fail "Backup storage is not mounted"
[[ -r "$STATUS_FILE" ]] || fail "Backup success marker is missing or unreadable"

backup_status="$(grep '^status=' "$STATUS_FILE" | cut -d= -f2-)"
completed="$(grep '^completed=' "$STATUS_FILE" | cut -d= -f2-)"

[[ "$backup_status" == "success" ]] || fail "Latest backup status is not success"
completed_epoch="$(date -d "$completed" +%s 2>/dev/null)" || fail "Backup completion timestamp is invalid"

age_seconds=$(( $(date +%s) - completed_epoch ))
age_hours=$(( age_seconds / 3600 ))
(( age_seconds <= MAX_AGE_SECONDS )) || fail "Backup is overdue: ${age_hours} hours old"

disk_usage="$(df --output=pcent "$BACKUP_MOUNT" | tail -n1 | tr -dc '0-9')"
available="$(df -h --output=avail "$BACKUP_MOUNT" | tail -n1 | xargs)"
(( disk_usage < MAX_DISK_PERCENT )) || fail "Backup storage is ${disk_usage}% full"

message="Healthy: latest backup ${age_hours}h old, disk ${disk_usage}% used, ${available} available"
send_result "up" "$message"
logger -t backup-health "$message"
