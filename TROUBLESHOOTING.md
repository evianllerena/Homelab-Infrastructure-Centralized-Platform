# Troubleshooting Case Studies

## 1. AdGuard Works Locally but Remote DNS Fails

### Symptoms

- AdGuard responds from the LAN.
- Remote device is connected to Tailscale.
- DNS filtering is not available away from home.

### Investigation

Validate each layer independently:

1. Tailscale daemon and interface state.
2. Server Tailscale address.
3. Docker/AdGuard container state.
4. UDP DNS on port 53.
5. TCP DNS on port 53.
6. Host firewall path through `tailscale0`.
7. Tailnet DNS configuration.
8. Remote-client DNS acceptance.
9. AdGuard query log.
10. Packet capture on `tailscale0` if required.

### Lesson

Remote connectivity and remote DNS are separate concerns. A device can be connected to the tailnet while still using another DNS resolver.

## 2. System Health Healthy, Backup Health Failing

### Symptoms

The general system-health service reported applications, mounts, and timers as operational, while a dedicated backup-health service repeatedly exited with failure.

### Why This Was Useful

The monitoring architecture avoided collapsing several health domains into one status. The failure could be isolated to backup validation/reporting instead of being mistaken for a server-wide outage.

### Investigation Pattern

```bash
systemctl --failed --no-legend
systemctl status backup-health.service --no-pager
journalctl -u backup-health.service --since today --no-pager
sudo /usr/local/sbin/backup-health
```

Validate separately:

```bash
mountpoint -q /mnt/backup
cat /mnt/backup/logs/last-success.txt
restic snapshots
restic check
```

## 3. Monitoring-Host Backup Validation

A monitoring-host backup was verified through:

- successful Restic snapshot creation;
- application of retention policy;
- repository integrity verification with no detected errors; and
- repeated successful backup-health checks confirming mount, repository, and disk-space status.

## Diagnostic Philosophy

Troubleshooting scripts default to **read-only checks**. Repair actions are explicit and separated from diagnostics. This reduces the chance of changing the system before evidence is collected.
