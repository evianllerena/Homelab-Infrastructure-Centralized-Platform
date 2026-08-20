# SANITIZED PORTFOLIO EXAMPLE
# Documentation addresses only. Review before use in any environment.
#!/usr/bin/env bash
# AdGuard Home + Tailscale Emergency Diagnostic and Recovery Tool
# Environment targeted:
#   Ubuntu host
#   AdGuard Home in Docker Compose
#   Compose file: /opt/adguardhome/compose.yaml
#   Environment file: /opt/adguardhome/.env
#   AdGuard LAN DNS: 192.0.2.10
#   AdGuard Tailscale DNS: 100.64.0.10
#   AdGuard dashboard: http://192.0.2.10:8083
#
# Default mode is read-only diagnostics.
# Use --repair to restart services and recreate AdGuard Home when needed.
# Use --capture to run a short DNS packet capture on tailscale0.

set -uo pipefail

SCRIPT_NAME="$(basename "$0")"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
REPORT_DIR="${REPORT_DIR:-$HOME/adguard-emergency-reports}"
REPORT_FILE="$REPORT_DIR/adguard-tailscale-report-$TIMESTAMP.txt"
LATEST_LINK="$REPORT_DIR/adguard-tailscale-report-LATEST.txt"

COMPOSE_FILE="${COMPOSE_FILE:-/opt/adguardhome/compose.yaml}"
ENV_FILE="${ENV_FILE:-/opt/adguardhome/.env}"
CONFIG_FILE="${CONFIG_FILE:-/opt/adguardhome/conf/AdGuardHome.yaml}"
CONTAINER_NAME="${CONTAINER_NAME:-adguardhome}"
LAN_DNS="${LAN_DNS:-192.0.2.10}"
TAILSCALE_DNS="${TAILSCALE_DNS:-100.64.0.10}"
DASHBOARD_URL="${DASHBOARD_URL:-http://192.0.2.10:8083}"
TAILSCALE_IFACE="${TAILSCALE_IFACE:-tailscale0}"

MODE="check"
DO_CAPTURE=0
CAPTURE_SECONDS="${CAPTURE_SECONDS:-15}"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

usage() {
  cat <<USAGE
Usage: sudo ./$SCRIPT_NAME [options]

Options:
  --check              Run diagnostics only. This is the default.
  --repair             Restart/enable services and recreate AdGuard if needed.
  --capture            Capture DNS traffic on tailscale0 for ${CAPTURE_SECONDS}s.
  --capture-seconds N  Set packet-capture duration.
  --help               Show this help.

Examples:
  sudo ./$SCRIPT_NAME
  sudo ./$SCRIPT_NAME --repair
  sudo ./$SCRIPT_NAME --repair --capture
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE="check"; shift ;;
    --repair) MODE="repair"; shift ;;
    --capture) DO_CAPTURE=1; shift ;;
    --capture-seconds)
      CAPTURE_SECONDS="${2:-}"
      [[ "$CAPTURE_SECONDS" =~ ^[0-9]+$ ]] || { echo "Invalid capture duration"; exit 2; }
      shift 2
      ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 2 ;;
  esac
done

mkdir -p "$REPORT_DIR"
exec > >(tee -a "$REPORT_FILE") 2>&1
ln -sfn "$REPORT_FILE" "$LATEST_LINK"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "ERROR: Run this script with sudo."
  exit 1
fi

command_exists() { command -v "$1" >/dev/null 2>&1; }

pass() { printf '[PASS] %s\n' "$*"; PASS_COUNT=$((PASS_COUNT+1)); }
warn() { printf '[WARN] %s\n' "$*"; WARN_COUNT=$((WARN_COUNT+1)); }
fail() { printf '[FAIL] %s\n' "$*"; FAIL_COUNT=$((FAIL_COUNT+1)); }
info() { printf '[INFO] %s\n' "$*"; }

section() {
  echo
  echo "================================================================"
  echo "$1"
  echo "================================================================"
}

run_described() {
  local description="$1"
  shift
  info "$description"
  printf 'Command: '
  printf '%q ' "$@"
  echo
  "$@"
}

compose() {
  docker --context default compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

check_command() {
  local cmd="$1"
  if command_exists "$cmd"; then
    pass "Required command is available: $cmd"
  else
    fail "Required command is missing: $cmd"
  fi
}

check_service_active() {
  local service="$1"
  if systemctl is-active --quiet "$service"; then
    pass "$service is active"
  else
    fail "$service is not active"
    if [[ "$MODE" == "repair" ]]; then
      info "Repair action: enabling and starting $service"
      systemctl enable --now "$service" || true
      if systemctl is-active --quiet "$service"; then
        pass "$service is active after repair"
      else
        fail "$service still failed after repair"
      fi
    fi
  fi
}

check_file() {
  local path="$1"
  local description="$2"
  if [[ -f "$path" ]]; then
    pass "$description exists: $path"
  else
    fail "$description is missing: $path"
  fi
}

check_dns() {
  local server="$1"
  local name="$2"
  local expected_type="$3"
  local output
  output="$(dig +time=4 +tries=1 @"$server" "$name" +short 2>&1 || true)"
  if [[ -n "$output" ]] && ! grep -qiE 'timed out|no servers could be reached|connection refused|communications error' <<<"$output"; then
    pass "DNS query succeeded: $name via $server"
    echo "$output" | sed 's/^/       /'
    if [[ "$expected_type" == "blocked" ]]; then
      if grep -qxE '0\.0\.0\.0|::' <<<"$output"; then
        pass "Ad blocking confirmed for $name via $server"
      else
        warn "$name was not blocked via $server"
      fi
    fi
  else
    fail "DNS query failed: $name via $server"
    echo "$output" | sed 's/^/       /'
  fi
}

check_tcp_dns() {
  local server="$1"
  local output
  output="$(dig +tcp +time=4 +tries=1 @"$server" example.com +short 2>&1 || true)"
  if [[ -n "$output" ]] && ! grep -qiE 'timed out|no servers could be reached|connection refused|communications error' <<<"$output"; then
    pass "TCP DNS works via $server"
    echo "$output" | sed 's/^/       /'
  else
    fail "TCP DNS failed via $server"
    echo "$output" | sed 's/^/       /'
  fi
}

section "ADGUARD HOME + TAILSCALE EMERGENCY REPORT"
echo "Generated: $(date --iso-8601=seconds)"
echo "Host: $(hostname)"
echo "Mode: $MODE"
echo "Report: $REPORT_FILE"
echo "Latest report link: $LATEST_LINK"

section "1. REQUIRED COMMANDS"
for cmd in docker systemctl tailscale dig curl ss ip grep awk sed timeout; do
  check_command "$cmd"
done
if command_exists tcpdump; then
  pass "Optional command is available: tcpdump"
else
  warn "Optional command is missing: tcpdump"
fi

section "2. REQUIRED FILES AND DIRECTORIES"
check_file "$COMPOSE_FILE" "Docker Compose configuration"
check_file "$ENV_FILE" "Docker environment file"
check_file "$CONFIG_FILE" "AdGuard Home configuration"
[[ -d /opt/adguardhome/work ]] && pass "AdGuard work directory exists" || fail "AdGuard work directory is missing"
[[ -d /opt/adguardhome/conf ]] && pass "AdGuard config directory exists" || fail "AdGuard config directory is missing"

section "3. CORE SERVICES"
check_service_active docker.service
check_service_active tailscaled.service

if [[ "$MODE" == "repair" ]]; then
  info "Repair action: forcing Tailscale shields-up off"
  tailscale set --shields-up=false || warn "Unable to set shields-up=false"
fi

SHIELDS_VALUE="$(tailscale debug prefs 2>/dev/null | grep -i 'ShieldsUp' | head -n1 || true)"
if grep -qi 'false' <<<"$SHIELDS_VALUE"; then
  pass "Tailscale ShieldsUp is false"
else
  warn "Unable to confirm ShieldsUp=false: ${SHIELDS_VALUE:-no output}"
fi

section "4. NETWORK ADDRESSES AND TAILSCALE STATUS"
run_described "Displays all IPv4 addresses on the server." ip -4 address show
run_described "Displays Tailscale peer and connection status." tailscale status

TS_IP="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
if [[ "$TS_IP" == "$TAILSCALE_DNS" ]]; then
  pass "Tailscale IPv4 matches expected address: $TAILSCALE_DNS"
elif [[ -n "$TS_IP" ]]; then
  warn "Current Tailscale IPv4 is $TS_IP; expected $TAILSCALE_DNS"
else
  fail "Unable to obtain Tailscale IPv4 address"
fi

if ip link show "$TAILSCALE_IFACE" >/dev/null 2>&1; then
  pass "$TAILSCALE_IFACE interface exists"
else
  fail "$TAILSCALE_IFACE interface is missing"
fi

section "5. DOCKER AND ADGUARD CONTAINER"
if docker info >/dev/null 2>&1; then
  pass "Docker engine is responding"
else
  fail "Docker engine is not responding"
fi

if [[ -f "$COMPOSE_FILE" && -f "$ENV_FILE" ]]; then
  run_described "Shows the current Docker Compose status for AdGuard Home." compose ps

  if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    CONTAINER_STATE="$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || true)"
    if [[ "$CONTAINER_STATE" == "running" ]]; then
      pass "AdGuard container is running"
    else
      fail "AdGuard container state is: ${CONTAINER_STATE:-unknown}"
    fi
  else
    fail "AdGuard container does not exist"
  fi

  if [[ "$MODE" == "repair" ]]; then
    info "Repair action: creating or recreating AdGuard Home with Docker Compose"
    compose up -d --remove-orphans || fail "Docker Compose repair failed"
    sleep 3
    if [[ "$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || true)" == "running" ]]; then
      pass "AdGuard container is running after repair"
    else
      fail "AdGuard container is not running after repair"
    fi
  fi
else
  fail "Cannot inspect Compose because the compose or env file is missing"
fi

section "6. DNS PORT BINDINGS"
run_described "Shows all processes listening on DNS port 53." ss -lntup

if ss -lntuH | grep -qE "${LAN_DNS//./\\.}:53|${TAILSCALE_DNS//./\\.}:53"; then
  pass "At least one expected AdGuard DNS binding is present"
else
  fail "Expected DNS bindings were not found on $LAN_DNS:53 or $TAILSCALE_DNS:53"
fi

if ss -lntH | grep -q "${LAN_DNS//./\\.}:8083"; then
  pass "AdGuard dashboard is listening on $LAN_DNS:8083"
else
  warn "AdGuard dashboard was not found on $LAN_DNS:8083"
fi

section "7. ADGUARD SAVED CONFIGURATION"
if [[ -f "$CONFIG_FILE" ]]; then
  info "Relevant AdGuard DNS configuration:"
  grep -nA25 -B2 'upstream_dns:' "$CONFIG_FILE" || true
  echo
  info "Access-control and DNSSEC/cache settings:"
  grep -nE 'allowed_clients|disallowed_clients|blocked_hosts|use_private_ptr_resolvers|local_ptr_upstreams|enable_dnssec|cache_size|optimistic_cache' "$CONFIG_FILE" || true

  if grep -q 'https://dns.quad9.net/dns-query' "$CONFIG_FILE"; then
    pass "Quad9 encrypted upstream is saved"
  else
    warn "Quad9 encrypted upstream is not found"
  fi

  if grep -q 'https://cloudflare-dns.com/dns-query' "$CONFIG_FILE"; then
    pass "Cloudflare encrypted upstream is saved"
  else
    warn "Cloudflare encrypted upstream is not found"
  fi

  if grep -q 'upstream_mode: load_balance' "$CONFIG_FILE"; then
    pass "Upstream mode is load balancing"
  else
    warn "Upstream mode is not load balancing"
  fi

  if grep -q 'use_private_ptr_resolvers: true' "$CONFIG_FILE"; then
    PTR_COUNT="$(awk '/local_ptr_upstreams:/{flag=1;next}/^[^ ]/{flag=0}flag&&/- /{count++}END{print count+0}' "$CONFIG_FILE")"
    if [[ "$PTR_COUNT" -eq 0 ]]; then
      fail "Private reverse DNS is enabled but no private reverse upstream is configured"
    else
      pass "Private reverse DNS is enabled with at least one resolver"
    fi
  else
    pass "Private reverse DNS resolver feature is disabled"
  fi
fi

section "8. DASHBOARD HTTP CHECK"
HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "$DASHBOARD_URL" 2>/dev/null || true)"
if [[ "$HTTP_CODE" =~ ^(200|301|302|303|307|308)$ ]]; then
  pass "AdGuard dashboard responded with HTTP $HTTP_CODE"
else
  fail "AdGuard dashboard check failed; HTTP result: ${HTTP_CODE:-none}"
fi

section "9. DNS FUNCTION TESTS"
check_dns "$LAN_DNS" example.com normal
check_tcp_dns "$LAN_DNS"
check_dns "$TAILSCALE_DNS" example.com normal
check_tcp_dns "$TAILSCALE_DNS"
check_dns "$TAILSCALE_DNS" doubleclick.net blocked
check_dns "$TAILSCALE_DNS" googleads.g.doubleclick.net blocked

section "10. BOOTSTRAP AND DOH ENDPOINT REACHABILITY"
check_dns 1.1.1.1 cloudflare-dns.com normal
check_dns 9.9.9.9 dns.quad9.net normal

CF_CODE="$(curl -sS -I -o /dev/null -w '%{http_code}' --max-time 10 https://cloudflare-dns.com/dns-query 2>/dev/null || true)"
if [[ "$CF_CODE" =~ ^(200|400|404|405|415)$ ]]; then
  pass "Cloudflare DoH HTTPS endpoint is reachable; HTTP $CF_CODE"
else
  warn "Cloudflare DoH endpoint returned: ${CF_CODE:-no response}"
fi

Q9_CODE="$(curl -sS -I -o /dev/null -w '%{http_code}' --max-time 10 https://dns.quad9.net/dns-query 2>/dev/null || true)"
if [[ "$Q9_CODE" =~ ^(200|400|404|405|415)$ ]]; then
  pass "Quad9 DoH HTTPS endpoint is reachable; HTTP $Q9_CODE"
else
  warn "Quad9 DoH endpoint returned: ${Q9_CODE:-no response}"
fi

section "11. RECENT ADGUARD LOGS"
if [[ -f "$COMPOSE_FILE" && -f "$ENV_FILE" ]]; then
  info "Last 15 minutes of errors, failures, refusals, and upstream problems:"
  LOG_ERRORS="$(compose logs --since 15m adguardhome 2>&1 | grep -iE 'error|failed|unexpected EOF|refused|timeout|panic|fatal' || true)"
  if [[ -n "$LOG_ERRORS" ]]; then
    warn "Recent AdGuard warnings/errors were found"
    echo "$LOG_ERRORS"
  else
    pass "No recent AdGuard error patterns were found"
  fi
fi

section "12. OPTIONAL TAILSCALE DNS PACKET CAPTURE"
if [[ "$DO_CAPTURE" -eq 1 ]]; then
  if command_exists tcpdump; then
    info "Capturing DNS traffic on $TAILSCALE_IFACE for ${CAPTURE_SECONDS}s"
    info "This confirms whether clients reach the server and whether replies are returned."
    timeout "$CAPTURE_SECONDS" tcpdump -ni "$TAILSCALE_IFACE" 'port 53' || true
  else
    warn "Packet capture skipped because tcpdump is not installed"
  fi
else
  info "Packet capture was not requested. Use --capture to enable it."
fi

section "13. REPAIR FOLLOW-UP"
if [[ "$MODE" == "repair" ]]; then
  info "Restarting AdGuard once more after repair actions"
  compose restart adguardhome || warn "Final AdGuard restart failed"
  sleep 3
  check_dns "$TAILSCALE_DNS" example.com normal
  check_dns "$TAILSCALE_DNS" doubleclick.net blocked
  info "Recent post-repair logs:"
  compose logs --since 3m adguardhome | grep -iE 'error|failed|unexpected EOF|refused|timeout|panic|fatal' || true
else
  info "No changes were made. Re-run with --repair to attempt service recovery."
fi

section "14. COMMAND REFERENCE"
cat <<'REFERENCE'
1. systemctl is-active docker.service
   Confirms that the Docker service is running.

2. systemctl enable --now docker.service
   Enables Docker at boot and starts it immediately.

3. systemctl is-active tailscaled.service
   Confirms that the Tailscale daemon is running.

4. systemctl enable --now tailscaled.service
   Enables Tailscale at boot and starts it immediately.

5. tailscale debug prefs | grep -i ShieldsUp
   Displays whether Tailscale Shields Up is enabled.

6. tailscale set --shields-up=false
   Allows inbound connections from permitted tailnet devices.

7. tailscale status
   Shows the local Tailscale device and peer connection state.

8. tailscale ip -4
   Displays the server's current Tailscale IPv4 address.

9. docker info
   Confirms that the Docker engine can respond to commands.

10. docker compose ps
    Shows whether the AdGuard Home container is running.

11. docker compose up -d --remove-orphans
    Creates, starts, or repairs the AdGuard Home Compose service.

12. docker compose restart adguardhome
    Restarts only the AdGuard Home service.

13. ss -lntup
    Shows TCP and UDP listening sockets, including DNS port 53.

14. grep -A25 upstream_dns AdGuardHome.yaml
    Displays encrypted upstream, bootstrap, fallback, and mode settings.

15. curl http://192.0.2.10:8083
    Confirms that the AdGuard dashboard responds over HTTP.

16. dig @192.0.2.10 example.com
    Tests AdGuard DNS through the LAN address.

17. dig @100.64.0.10 example.com
    Tests AdGuard DNS through the Tailscale address.

18. dig +tcp @SERVER example.com
    Confirms DNS-over-TCP works, not only UDP.

19. dig @100.64.0.10 doubleclick.net
    Confirms that DNS filtering returns a blocked address.

20. dig @1.1.1.1 cloudflare-dns.com
    Confirms Cloudflare bootstrap resolution.

21. dig @9.9.9.9 dns.quad9.net
    Confirms Quad9 bootstrap resolution.

22. curl -I https://cloudflare-dns.com/dns-query
    Confirms the Cloudflare HTTPS endpoint is reachable.

23. curl -I https://dns.quad9.net/dns-query
    Confirms the Quad9 HTTPS endpoint is reachable.

24. docker compose logs --since 15m adguardhome
    Displays recent AdGuard startup and DNS-proxy messages.

25. tcpdump -ni tailscale0 'port 53'
    Shows DNS requests and responses crossing the Tailscale interface.
REFERENCE

section "15. FINAL STATUS"
echo "PASS: $PASS_COUNT"
echo "WARN: $WARN_COUNT"
echo "FAIL: $FAIL_COUNT"
echo "Report saved to: $REPORT_FILE"
echo "Latest report link: $LATEST_LINK"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "OVERALL STATUS: FAILED - review the [FAIL] lines above."
  exit 1
elif [[ "$WARN_COUNT" -gt 0 ]]; then
  echo "OVERALL STATUS: OPERATIONAL WITH WARNINGS"
  exit 0
else
  echo "OVERALL STATUS: HEALTHY"
  exit 0
fi
