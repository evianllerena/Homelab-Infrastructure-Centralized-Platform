# Remote DNS Filtering with AdGuard Home and Tailscale

## Objective

Use the same AdGuard filtering policy when away from the local network without exposing a public recursive DNS service.

## Design

```text
Remote Device
    |
    | encrypted Tailscale tunnel
    v
Tailscale IP on Ubuntu host
    |
    v
AdGuard Home :53/TCP + :53/UDP
    |
    v
Configured upstream resolvers
```

## Required Conditions

- Docker publishes AdGuard DNS on TCP and UDP port 53.
- AdGuard listens on an address reachable from the Tailscale interface.
- The host firewall permits port 53 through `tailscale0`.
- The tailnet DNS configuration uses the AdGuard server's Tailscale address as a nameserver.
- Remote clients accept Tailscale DNS configuration.

## Example Firewall Rules

```bash
sudo ufw allow in on tailscale0 to any port 53 proto udp
sudo ufw allow in on tailscale0 to any port 53 proto tcp
```

Do **not** create an Internet-facing router port-forward for DNS.

## Testing

Replace the documentation address with the real Tailscale address locally; never commit the real value.

```bash
dig @100.64.0.10 example.com
dig +tcp @100.64.0.10 example.com
```

Then validate that a known filtered test domain appears in the AdGuard query log.

## Exit Node vs DNS Resolver

- **Remote DNS filtering:** Tailscale DNS + AdGuard; exit node not required.
- **Access private LAN subnets:** use a subnet router where appropriate.
- **Route all Internet traffic through home:** use a Tailscale exit node.
