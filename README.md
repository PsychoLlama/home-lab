# Home Lab

Declarative infrastructure for my home lab.

> 🔴 Disclaimer: I'm a noob.

Stack:

| Category | Tool |
|----------|------|
| Operating System | [NixOS](https://nixos.org/) |
| Provisioning Tools | [NixOps](https://github.com/NixOS/nixops) & [Terraform](https://www.terraform.io/) |
| Service Discovery | [Consul](https://www.consul.io/) |
| Container Orchestration | [Nomad](https://www.nomadproject.io/) |
| Storage Backend | [TrueNAS](https://www.truenas.com/) |
| Network Configuration | [OPNSense](https://opnsense.org/) |

Most of this is automated, but without good Terraform providers for TrueNAS/OPNSense, those services are still managed manually.

## Structure

- `machines/`: provisions physical resources & manages operating systems
  - `hosts/`: host-level configuration
  - `hardware/`: settings for different hardware classes (e.g. Raspberry Pi)
- `infrastructure/`: higher-level terraform configs and service definitions
