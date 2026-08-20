# GitHub Publishing Checklist

Before publishing:

- [ ] Search the repository for real RFC1918 addresses used by the environment.
- [ ] Search for Tailscale 100.x addresses and tailnet DNS names.
- [ ] Search for `api`, `token`, `secret`, `password`, `push`, and `key`.
- [ ] Confirm all `.env` files are excluded.
- [ ] Confirm no raw logs contain usernames, hostnames, device names, or external IP addresses.
- [ ] Confirm screenshots do not expose browser tabs, account names, IP addresses, serial numbers, or tokens.
- [ ] Replace real hostnames with roles such as `production-host` and `monitoring-host`.
- [ ] Review Git history, not only the current working tree, before making the repository public.
- [ ] Add screenshots only after manually redacting sensitive information.
- [ ] Run a secret scanner such as Gitleaks before publishing.
