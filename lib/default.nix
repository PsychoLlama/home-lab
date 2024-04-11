flake-inputs:

{
  defineHost = import ./define-host.nix flake-inputs;
  deviceProfiles = import ./device-profiles.nix flake-inputs;
  makeImage = import ./make-image.nix;
}
