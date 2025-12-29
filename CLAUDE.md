# Home Lab

NixOS configurations for my home lab infrastructure.

## Architecture

Modules live under `platforms/<platform>/modules/lab/` (nixos, home-manager). Three layers:

- **Presets** (`presets/`): Opinionated config for exactly one program. Self-contained and reusable.
- **Services** (`services/`): Higher-level DSL abstracting a program. Reusable, but may reference other services and shared config (`lab.networks`, `lab.host`, etc).
- **Stacks** (`stacks/`): Combine presets and services into a role (e.g., `router`, `file-server`). Specific to this lab.

Hosts in `hosts/` are minimal—they adopt stacks and add hardware-specific overrides.

## Testing

Tests mirror the filesystem under `platforms/nixos/tests/`:

```sh
nix build .#tests.dhcp  # platforms/nixos/tests/dhcp.nix
```

## Building

Test builds locally with colmena:

```sh
colmena build --on @rpi4        # all rpi4 devices
colmena build --on rpi4-001     # specific host
colmena build --on nas-001      # NAS device
```

## Deploying

Always use `test` activation (not `switch`) unless explicitly asked:

```sh
colmena apply test --on rpi4-001 --evaluator streaming
```

This activates the config without adding it to the boot menu - safer for remote changes.

## Formatting

Always run `just fmt` before committing.

## Infrastructure

OpenTofu (`tofu`) manages external infrastructure in `terraform/`:

- **Cloudflare**: DNS for `selfhosted.city`
- **Tailscale**: ACL policies

Config is generated from Nix via Terranix (`terraform/*.nix`). It pulls from the colmena hive—virtualHosts become DNS records, service tags become ACL grants.

```sh
just tf-gen    # Generate terraform/config.tf.json from Nix
just tf-apply  # Generate + apply
```

Credentials come from `TF_VAR_*` env vars (see `.env`).

Tailscale bypasses the firewall, so don't open ports for inter-host traffic.

## Tools

- Use `tofu`, not `terraform`
- Use `doggo`, not `dig`
