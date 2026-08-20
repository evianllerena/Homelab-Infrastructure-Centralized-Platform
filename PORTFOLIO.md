# Portfolio Summary

## Secure Self-Hosted Infrastructure and Monitoring Platform

Designed and implemented a two-host Linux homelab that separates application workloads from monitoring and observability. The environment combines containerized DNS filtering, private remote access, self-hosted services, centralized metrics/logging, automated backups, and system-level health reporting.

### Engineering Highlights

- Deployed AdGuard Home in Docker and extended filtered DNS to remote devices using Tailscale without exposing DNS publicly.
- Implemented an independent monitoring server running Uptime Kuma, Grafana, Prometheus, Loki, Grafana Alloy, Netdata, Cockpit, and Node Exporter.
- Built custom Bash health checks and systemd timers for application availability, mount state, disk thresholds, and backup freshness.
- Implemented Restic-based backups with retention and repository integrity verification.
- Built a diagnostic/recovery utility that validates Docker, Tailscale, DNS over UDP/TCP, blocked-domain behavior, service reachability, logs, and optional packet capture.
- Designed monitoring so a failed component can be isolated without incorrectly declaring the entire host unavailable.
- Applied security controls focused on private management planes, least privilege, secret separation, and sanitized troubleshooting output.

### Business / Operational Value

The project demonstrates the ability to take a small infrastructure environment from individual services to an operational platform with monitoring, recovery, repeatable automation, and documented troubleshooting procedures. The same patterns translate directly to SMB/MSP environments: service visibility, secure remote administration, backup assurance, centralized logging, and reduced dependency on manual checks.

### Relevant Roles

This project is relevant to roles involving:

- Systems Administration
- Network Administration
- Infrastructure Engineering
- Cloud / Platform Operations
- DevOps / SRE fundamentals
- MSP / MSSP Engineering
- Security Operations and Infrastructure Security
