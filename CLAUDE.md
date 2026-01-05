# Home Lab

NixOS configurations for my home lab infrastructure.

## Architecture

Modules live under `platforms/<platform>/modules/lab/` (nixos, home-manager). Three layers:

- **Presets** (`presets/`): Opinionated config for exactly one program. Self-contained and reusable.
- **Services** (`services/`): Higher-level DSL abstracting a program. Reusable, but may reference other services and shared config (`lab.networks`, `lab.host`, etc).
- **Stacks** (`stacks/`): Combine presets and services into a role (e.g., `router`, `file-server`). Specific to this lab.

Hosts in `hosts/` are minimal—they adopt stacks and add hardware-specific overrides.

## ACL Tags

Services and stacks expose read-only `acl.tag` options for Tailscale ACL management. This centralizes tag definitions and enables type-safe cross-references.

**Defining tags** (in services/stacks):

```nix
acl.tag = lib.mkOption {
  type = lib.types.str;
  readOnly = true;
  default = "ntfy";  # or "router", "ingress", etc.
  description = "Tailscale ACL tag for this service";
};
```

**Referencing tags** (via `nodes`):

```nix
# In a module that needs another host's tag
{ nodes, ... }:
{
  acl.tag = nodes.rpi4-002.config.lab.services.ntfy.acl.tag;
}
```

**Prometheus ACL tags**: Services exposing metrics also define `prometheus.acl.tag` (usually derived from their parent's `acl.tag`). These are collected by `pkgs/terraform-config` to generate monitoring grants automatically—no need to hard-code them in `tailscale.tf`.

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
colmena apply test --on rpi4-001
```

This activates the config without adding it to the boot menu - safer for remote changes.

**Note:** Do not use `--evaluator streaming` with `colmena apply`. It has a bug where it silently skips the build/deploy phase after evaluation, reporting success without actually deploying. Safe to use with `colmena build` only.

## Formatting

Always run `just fmt` before committing.

## Infrastructure

OpenTofu (`tofu`) manages external infrastructure in `terraform/`:

- **Cloudflare**: DNS for `selfhosted.city`
- **Tailscale**: ACL policies

HCL files in `terraform/*.tf` consume JSON data exported from colmena nodes via `pkgs/terraform-config`. VirtualHosts become DNS records, service tags become ACL grants.

```sh
just tf-gen    # Generate terraform/config.json from Nix
just tf-apply  # Generate + apply
```

Credentials come from `TF_VAR_*` env vars (see `.env`).

Tailscale bypasses the firewall, so don't open ports for inter-host traffic.

## Tools

- Use `tofu`, not `terraform`
- Use `doggo`, not `dig`
- SSH targets run nushell—prefix commands with `bash -c '...'`
