# Architecture

## Logical Design

The platform uses two Linux systems with separate responsibilities.

### Production Host

Responsibilities:

- AdGuard Home DNS filtering
- Nextcloud
- Docker application runtime
- Tailscale private connectivity
- host metrics exporter
- log forwarding agent
- backup and health automation

### Monitoring Host

Responsibilities:

- Uptime Kuma service monitoring
- Prometheus metrics collection
- Grafana visualization
- Loki log aggregation
- Grafana Alloy log forwarding
- Netdata real-time monitoring
- Cockpit administration
- independent backup and backup-health monitoring

## Why Two Hosts?

A monitoring system hosted only on the server it monitors has an obvious blind spot: when that server fails, the monitoring platform disappears with it. Separating the monitoring plane improves fault visibility and provides an independent place to receive health information.

## Data Flows

1. Node Exporter exposes host metrics to Prometheus.
2. Prometheus stores time-series metrics.
3. Grafana queries Prometheus for dashboards.
4. Alloy forwards relevant logs/journals to Loki.
5. Grafana queries Loki for centralized logs.
6. Custom health scripts push service state to Uptime Kuma.
7. Restic writes snapshots to dedicated backup storage.
8. Backup-health scripts validate last-success age, mount state, repository availability, and disk utilization.
9. Tailscale provides encrypted remote paths to selected private services.
