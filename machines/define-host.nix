# Creates a top-level NixOS config, applied to all machines in the home lab.
# This is responsible for setting the baseline configuration.

hostName:
{ config, lib, pkgs, ... }:

let
  inherit (import ./config) domain certificates;
  unstable = import ./unstable-pkgs.nix { system = pkgs.system; };

in with lib; {
  imports = [ ./services (./hosts + "/${hostName}") ];

  lab.administration.enable = lib.mkDefault true;

  # Match the directory name to the host's name.
  networking.hostName = mkDefault hostName;

  # All hosts are addressed as `{host}.host.{domain}`.
  networking.domain = "host.${domain}";

  deployment.targetHost = config.networking.fqdn;

  # These are self-signed root certificates issued by Vault.
  security.pki.certificates = certificates;

  # Using a dedicated PEM file for self-signed certificates allows services to
  # reject all connections except those signed by Vault.
  environment.etc."ssl/certs/home-lab.crt" = {
    text = concatStringsSep "\n" certificates;
    mode = "0444";
  };

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
