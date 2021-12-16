{ config, lib, pkgs, ... }:

let
  cfg = config.services.secret-manager;
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };

in with lib; {
  options.services.secret-manager = {
    enable = mkEnableOption "Run HashiCorp Vault";
  };

  config = mkIf cfg.enable {
    services.vault = {
      enable = true;
      package = unstable.vault;
      address = config.networking.fqdn;
      # TODO: Persist state to Consul.
    };

    environment.systemPackages = [ unstable.vault ];

    # Vault Server + HA Coordination.
    networking.firewall.allowedTCPPorts = [ 8200 8201 ];
  };
}
