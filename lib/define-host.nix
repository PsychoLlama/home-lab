# Creates a top-level NixOS config, applied to all machines in the home lab.
# This is responsible for setting the baseline configuration.

hostName: modulePath:

{ config, lib, pkgs, ... }:

let inherit (config.lab.settings) domain;

in with lib; {
  imports = [ ../modules/nixos/lab modulePath ];

  # Match the directory name to the host's name.
  networking.hostName = mkDefault hostName;

  # All hosts are addressed as `{host}.host.{domain}`.
  networking.domain = "host.${domain}";

  deployment.targetHost = config.networking.fqdn;

  # Enable flakes.
  nix = {
    # Run garbage collection on a schedule.
    gc.automatic = true;

    # Use hard links to save disk space.
    optimise.automatic = true;

    package = pkgs.unstable.nix;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  services.openssh = {
    enable = true;
    passwordAuthentication = false;
  };

  users.users.root.openssh.authorizedKeys.keyFiles =
    [ ./keys/deploy.pub ./keys/admin.pub ];
}
