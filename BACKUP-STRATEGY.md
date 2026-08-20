# Backup Strategy

## Goals

A backup is not considered healthy merely because a timer ran. Health validation should confirm the data path and recovery prerequisites.

Checks include:

- backup storage is mounted;
- the last-success marker exists and reports success;
- the last successful backup is within an allowed age;
- the backup repository is reachable;
- backup storage has sufficient free capacity; and
- Restic repository integrity is periodically verified.

## Retention

The implemented workflow uses a rolling retention window. The portfolio environment validated a 30-day retention policy on the monitoring-host repository.

## Application Consistency

Where an application contains a database or stateful files, the backup workflow should either use an application-supported snapshot method or briefly quiesce the relevant service. In the monitoring environment, the backup workflow handled Uptime Kuma consistently before creating the Restic snapshot and then restored service operation.

## Health Reporting

Backup-health checks execute independently from the backup itself. This prevents a scheduler from appearing healthy when backups have silently become stale.

Example failure conditions:

- mount missing;
- last-success marker missing;
- last backup failed;
- last success too old;
- repository unavailable; or
- disk utilization above threshold.
