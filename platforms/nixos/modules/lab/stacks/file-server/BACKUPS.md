# Restic Backups

Backup server at `restic.selfhosted.city` (Tailscale only, append-only).

## Naming

- Workstations: `workstation-<hostname>`
- Servers: `server-<hostname>`

## Adding a Client

```sh
# Generate password hash
nix run nixpkgs#mkpasswd -- -m bcrypt

# Update htpasswd secret
agenix -d platforms/nixos/modules/lab/services/restic-server/restic-htpasswd.age > /tmp/htpasswd
echo 'workstation-newhost:<hash>' >> /tmp/htpasswd
agenix -e platforms/nixos/modules/lab/services/restic-server/restic-htpasswd.age < /tmp/htpasswd
rm /tmp/htpasswd

# Deploy
colmena apply test --on nas-001
```

## Client Usage

```sh
export RESTIC_REPOSITORY="rest:https://workstation-myhost:PASSWORD@restic.selfhosted.city/workstation-myhost/"
export RESTIC_PASSWORD="your-encryption-passphrase"

restic init          # one-time
restic backup ~/Documents
restic snapshots
```
