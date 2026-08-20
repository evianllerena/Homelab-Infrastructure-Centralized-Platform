# Security Notes

## Public Repository Sanitization

This repository must never contain:

- real public or private IP addressing tied to the environment;
- Tailscale device IPs, tailnet names, auth keys, node keys, or API tokens;
- Uptime Kuma push URLs/tokens;
- passwords, private keys, recovery keys, or session cookies;
- real hostnames or personally identifying device names;
- unredacted exported application configuration containing credentials; or
- raw diagnostic reports without review.

The example network uses RFC 5737 documentation ranges where addresses are needed.

## Exposure Model

Management interfaces should be reachable only from trusted LAN or Tailscale paths. Avoid forwarding these services directly from an Internet-facing router:

- DNS TCP/UDP 53
- AdGuard administrative UI
- Grafana
- Prometheus
- Loki
- Netdata
- Cockpit
- Uptime Kuma

## Secret Handling

Push URLs and repository secrets are loaded from environment files rather than embedded in scripts.

Recommended permissions:

```bash
sudo chown root:root /etc/homelab-monitoring/*.env
sudo chmod 600 /etc/homelab-monitoring/*.env
```

Commit only `.env.example` files containing placeholders.

## Firewall Principle

Permit only the interfaces and source networks that require access. For remote DNS, allow TCP/UDP 53 on the Tailscale interface instead of opening DNS globally to the Internet.
