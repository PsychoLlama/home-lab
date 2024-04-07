# Home Lab

A set of [NixOS](https://nixos.org/) modules for building your own on-premise cloud (according to a hobbyist).

## Project Status

:construction: Under Construction :construction:

This is undergoing a rewrite to incorporate learnings from a few years of working with NixOS. See [ye-olden-days](https://github.com/PsychoLlama/home-lab/tree/ye-olden-days) for a more elaborate, albiet messy example.

## Components

### Router

The router module configures a router (nat, dhcp, dns, ...) and manages the network for everything else in the lab.

### File Server

The file storage module manages ZFS pools and datasets. A host profile attaches Syncthing and adds snapshotting.

### Tests

Tests live in [nixos/tests](https://github.com/PsychoLlama/home-lab/tree/main/nixos/tests) and can be executed with `project test <path>`.

## Inspiration

The Nix Tradition is reading source code until you figure it out. Here are resources that helped me.

- [bitte](https://github.com/input-output-hk/bitte)
- [hlissner's dotfiles](https://github.com/hlissner/dotfiles/)
- [ideas for a NixOS router](https://francis.begyn.be/blog/nixos-home-router)
