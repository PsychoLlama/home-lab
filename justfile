_:
  just --list

# Build a bootable image for a specific host.
bootstrap host arch="aarch64-linux":
    nix build ".#packages.{{arch}}.{{host}}-image"
    readlink -f result

# Enter a VM sandbox for experimentation.
sandbox:
    nix run ".#tests.sandbox.driver"

# Run one of the VM tests under `nixos/tests`.
test expr:
    nix run ".#tests.{{expr}}.driver"
