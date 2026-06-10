# Home Lab

A set of [NixOS](https://nixos.org/) modules turning cheap hardware into a self-hosting powerhouse of technical debt.

I'm a terrible sysadmin but it's a fun way to burn weekends.

## Notable Bits

### The Router

The router module configures a router (nat, dhcp, dns, ...) and manages the network for everything else in the lab.

Losing the network brings big sadness so those components are heavily tested.

Run 'em with `just test <name>`:

```bash
# Example:
just test dns
```

See [all the tests here](https://github.com/PsychoLlama/home-lab/tree/main/platforms/nixos/tests). Or, cripple your machine by running all the tests:

```bash
nix build --verbose '.#tests'
```

### File Server

A [little CM3588 with SSDs](https://blog.psychollama.io/nixos-on-a-cm3588/) cosplaying as a file server. Manages a ZFS pool with Syncthing, Restic backups, and the hopes and dreams of the american people.

### Observability Stack

Grafana in a trenchcoat.

### Home Automation

Home Assistant with permission grants to my most private data, yeeted into Grafana, and thrown with reckless abandon into Claude via MCP.

### VPN

Split-horizon DNS over my `selfhosted.city` domain. Internal services are only accessible over the tailnet, and public services routed through a Caddy ingress. I understood how it worked, once.

## Project Structure

- `platforms/home-manager/modules`: QOL configs for remote administration.
- `platforms/nixos/modules/lab`: Library modules for building a home lab, layered as services and stacks.
- `platforms/nixos/tests`: Virtual machine tests for services in `modules/lab`.
- `hosts`: Per-host configurations. They are thin wrappers around stacks.

## Inspiration

The Nix Tradition is reading source code until you figure it out. Here are resources that helped me.

- [bitte](https://github.com/input-output-hk/bitte)
- [hlissner's dotfiles](https://github.com/hlissner/dotfiles/)
- [ideas for a NixOS router](https://francis.begyn.be/blog/nixos-home-router)
