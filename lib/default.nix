flake-inputs:

{
  defineHost = import ./define-host.nix;
  deviceProfiles = import ./device-profiles.nix flake-inputs;
}
