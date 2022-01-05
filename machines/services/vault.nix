{ config, lib, pkgs, ... }:

let
  cfg = config.lab.vault;
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };

in with lib; {
  options.lab.vault = { enable = mkEnableOption "Run HashiCorp Vault"; };

  config = mkIf cfg.enable {
    services.vault = {
      enable = true;
      package = unstable.vault;
      address = "0.0.0.0:8200";
      storageBackend = "consul";
    };

    environment.systemPackages = [ unstable.vault ];

    networking.firewall.allowedTCPPorts = [
      8200 # Vault Server
      8201 # HA Coordination.
    ];

    # The Consul storage backend assumes we're running a local agent.
    # HashiCorp recommends against going over the network.
    lab.consul.enable = mkDefault true;
  };
}
