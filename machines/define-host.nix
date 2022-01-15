# Creates a top-level NixOS config, applied to all machines in the home lab.
# This is responsible for setting the baseline configuration.

let inherit (import ./config.nix) domain;

in hostName:
{ config, lib, pkgs, ... }:
let unstable = import ./unstable-pkgs.nix { system = pkgs.system; };

in {
  imports = [ ./services (./hosts + "/${hostName}") ];

  lab.administration.enable = lib.mkDefault true;

  # Match the directory name to the host's name.
  networking.hostName = lib.mkDefault hostName;

  # All hosts are addressed as `{host}.host.{domain}`.
  networking.domain = "host.${domain}";

  deployment.targetHost = config.networking.fqdn;

  # Enable flakes.
  nix = {
    # Run garbage collection on a schedule.
    gc.automatic = true;

    # Use hard links to save disk space.
    optimise.automatic = true;

    package = unstable.nix;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  users.users.root.openssh.authorizedKeys.keyFiles =
    [ ./keys/deploy.pub ./keys/admin.pub ];
}
