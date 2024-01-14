default:
  just --list

target_arch := "aarch64-linux"

# Build a bootable image for a specific host.
bootstrap host:
  nix build ".#packages.{{target_arch}}.{{host}}-image"
  readlink result
