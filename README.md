# Home Lab

Declarative infrastructure for my home lab.

Stack:

| Category                | Tool                                                                                             |
| ----------------------- | ------------------------------------------------------------------------------------------------ |
| Operating System        | [NixOS](https://nixos.org/)                                                                      |
| Provisioning Tools      | [Colmena](https://github.com/zhaofengli/colmena) & [Terraform](https://www.terraform.io/)        |
| Service Discovery       | [Consul](https://www.consul.io/)                                                                 |
| Container Orchestration | [Nomad](https://www.nomadproject.io/)                                                            |
| Secrets Management      | [Vault](https://www.vaultproject.io/)                                                            |
| Storage Backend         | [ZFS](https://github.com/openzfs/zfs) & [NFS](https://en.wikipedia.org/wiki/Network_File_System) |
| DNS                     | [CoreDNS](https://coredns.io/)                                                                   |

The network is managed declaratively by a Raspberry Pi 3 configured to act as a router (see [here](./machines/hosts/viki/default.nix) and [here](./machines/services/router.nix)).

## Structure

- `machines/`: provisions physical resources & manages operating systems
  - `hosts/`: host-level configuration
  - `hardware/`: settings for different hardware classes (e.g. Raspberry Pi)
  - `services/`: custom services run on the hosts
- `infrastructure/`: higher-level terraform configs and service definitions
- `tests/`: automated QEMU tests
