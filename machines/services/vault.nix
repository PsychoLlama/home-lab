{ config, lib, pkgs, ... }:

let
  cfg = config.lab.vault;
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };
  key = file: {
    user = "vault";
    group = "vault";
    permissions = "440";
    text = builtins.readFile file;
  };

in with lib; {
  options.lab.vault.enable = mkEnableOption "Run HashiCorp Vault";

  config = mkIf cfg.enable {
    deployment.keys = {
      vault-tls-cert = key ../../vault.cert;
      vault-tls-key = key ../../vault.key;
    };

    users.users.vault.extraGroups = [ "keys" ];
    services.vault = {
      enable = true;
      package = unstable.vault;
      address = "0.0.0.0:8200";
      storageBackend = "consul";
      tlsCertFile = "/run/keys/vault-tls-cert";
      tlsKeyFile = "/run/keys/vault-tls-key";
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
