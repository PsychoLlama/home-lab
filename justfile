set indentation := "  "
set default-list

# Infrastructure recipes live in `terraform/justfile`.
mod terraform

# Format the codebase.
fmt:
  treefmt

# Check formatting without applying changes.
fmt-check:
  treefmt --fail-on-change

# Run one of the VM tests under `nixos/tests`.
test expr:
  @nix run ".#checks.$(nix eval --impure --raw --expr builtins.currentSystem).{{ expr }}.driver"

# Update all flake inputs.
update:
  nix flake update

# Run all checks.
check:
  just fmt-check
  nix flake check
