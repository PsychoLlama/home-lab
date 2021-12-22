{ config, lib, pkgs, ... }:

let
  cfg = config.lab.secret-manager;
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };

in with lib; {
  options.lab.secret-manager = {
    enable = mkEnableOption "Run HashiCorp Vault";
  };

  config = mkIf cfg.enable {
    services.vault = {
      enable = true;
      package = unstable.vault;
      address = "0.0.0.0:8200";
      storageBackend = "consul";
      extraConfig = ''
        cluster_address = "http://${config.networking.fqdn}:8201"
        api_addr = "http://${config.networking.fqdn}:8200"
      '';
    };

    environment.systemPackages = [ unstable.vault ];

    # Vault Server + HA Coordination.
    networking.firewall.allowedTCPPorts = [ 8200 8201 ];
  };
}
