# Creates a top-level NixOS config, applied to all machines in the home lab.
# This is responsible for setting the baseline configuration.
{ clapfile, ... }:

hostName: host:

{ config, lib, pkgs, ... }:

let inherit (config.lab) domain;

in {
  imports = [ ../nixos/modules host.profile host.module ];

  options.admin = lib.mkOption {
    description = "Manages the system admin toolkit";

    type = lib.types.submoduleWith {
      specialArgs.pkgs = pkgs;
      modules = [
        clapfile.nixosModules.default
        { options.enable = lib.mkEnableOption "System administration toolkit"; }
      ];
    };
  };

  config = {
    deployment.targetHost = config.networking.fqdn;

    admin = {
      enable = lib.mkDefault true;

      command = {
        name = "admin";
        about = "System administration toolkit";
      };
    };

    environment.systemPackages =
      lib.mkIf config.admin.enable [ config.admin.program ];

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
  };
}
