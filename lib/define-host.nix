# Creates a top-level NixOS config, applied to all machines in the home lab.
# This is responsible for setting the baseline configuration.
inputs: hostName: host:

{ config, lib, pkgs, ... }:

let inherit (config.lab) domain;

in {
  imports = [
    inputs.clapfile.nixosModules.nixos
    ../nixos/modules
    host.profile
    host.module
  ];

  deployment.targetHost = config.networking.fqdn;

  networking = {
    hostName = lib.mkDefault hostName;
    domain = "host.${domain}";
  };

  lab.host = host;

  nix = {
    # Run garbage collection on a schedule.
    gc.automatic = true;

    # Use hard links to save disk space.
    optimise.automatic = true;

    # Enable Flake support.
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  users.users.root.openssh.authorizedKeys.keyFiles =
    [ ./keys/deploy.pub ./keys/admin.pub ];
}
