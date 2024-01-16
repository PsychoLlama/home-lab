default:
    just --list

target_arch := "aarch64-linux"

# Build a bootable image for a specific host.
bootstrap host:
    nix build ".#packages.{{ target_arch }}.{{ host }}-image"
    readlink result

# Run a test from `nixos/tests`.
test drv_path:
    nix build ".#tests.{{ drv_path }}"

# Run a test interactively. Requires `.shell_interact()` in the test script.
test-interactive drv_path:
    just test "{{ drv_path }}.driver"
    ./result/bin/nixos-test-driver
