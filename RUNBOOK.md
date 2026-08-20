# Operations Runbook

## Daily / Routine Checks

```bash
systemctl --failed --no-legend
systemctl list-timers --all
```

Review:

- Uptime Kuma service state
- Grafana infrastructure dashboard
- backup-health monitors
- disk utilization
- failed systemd units

## AdGuard

```bash
sudo docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
sudo ss -lntup | grep ':53'
dig @<LAN_DNS> example.com
dig @<TAILSCALE_DNS> example.com
```

## Tailscale

```bash
tailscale status
tailscale ip -4
ip link show tailscale0
```

## Backup

```bash
mountpoint -q /mnt/backup
restic snapshots
restic check
```

## Logs

```bash
journalctl -p warning..alert --since today
journalctl -u <service-name> --since today --no-pager
```

## Monitoring Stack

Validate the service/container state for:

- Uptime Kuma
- Prometheus
- Grafana
- Loki
- Alloy
- Netdata
- Node Exporter

The exact deployment method can vary by host; do not expose administrative ports publicly.
