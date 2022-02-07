{ nodes, config, lib, pkgs, ... }:

with lib;

let
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };
  cfg = config.lab.vault-server;
  otherVaultServers = filter (node:
    node.config.lab.vault-server.enable && node.config.networking.fqdn
    != config.networking.fqdn) (attrValues nodes);

in {
  options.lab.vault-server = {
    enable = mkEnableOption "Run a Vault server";
    settings = mkOption {
      description = "Generated config given to Vault";
      type = types.anything;
      default = { };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ unstable.vault ];

    lab.vault-server.settings = {
      service_registration.consul.address = mkDefault "127.0.0.1:8500";
      cluster_addr = mkDefault "http://${config.networking.fqdn}:8201";
      api_addr = mkDefault "http://${config.networking.fqdn}:8200";

      listener.tcp = {
        address = mkDefault "0.0.0.0:8200";
        tls_disable = mkDefault true;
      };

      storage.raft = {
        path = mkDefault
          config.systemd.services.vault.serviceConfig.WorkingDirectory;

        node_id = mkDefault config.networking.hostName;
        retry_join = mkDefault (forEach otherVaultServers (node: {
          leader_api_addr = "http://${node.config.networking.fqdn}:8200";
        }));
      };
    };

    users.groups.vault.gid = config.ids.gids.vault;
    users.users.vault = {
      description = "Vault daemon user";
      name = "vault";
      group = "vault";
      uid = config.ids.uids.vault;
    };

    systemd.services.vault = {
      description = "Vault server daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      # Restarting the service seals Vault and causes a disruption. Most
      # configuration changes can be done through a live reload.
      restartIfChanged = false;
      startLimitIntervalSec = 60;
      startLimitBurst = 3;

      script = ''
        exec ${unstable.vault}/bin/vault server -config /etc/vault/config.json
      '';

      serviceConfig = {
        User = "vault";
        Group = "vault";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        PrivateDevices = true;
        KillSignal = "SIGINT";
        TimeoutStopSec = "30s";
        Restart = "on-failure";
        PrivateTmp = true;
        ProtectSystem = "full";
        ProtectHome = "read-only";
        StateDirectory = mkDefault "vault";
        WorkingDirectory = mkDefault "/var/lib/vault";
        NoNewPrivileges = true;

        # Avoids swapping the decryption key to disk.
        AmbientCapabilities = "cap_ipc_lock";
        LimitCORE = 0;
      };
    };

    networking.firewall.allowedTCPPorts = [
      8200 # Vault Server
      8201 # HA Coordination.
    ];

    environment.etc."vault/config.json" = {
      mode = "440";
      group = "vault";
      user = "vault";
      source =
        (pkgs.formats.json { }).generate "vault-config.json" cfg.settings;
    };
  };
}
