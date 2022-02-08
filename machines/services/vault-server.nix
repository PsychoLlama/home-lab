{ nodes, config, lib, pkgs, ... }:

with lib;

let
  inherit (import ../config) domain datacenter;
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };
  cfg = config.lab.vault-server;
  localIp = config.lab.network.ipAddress;
  scheme = if cfg.tls.enable then "https" else "http";
  otherVaultServers = filter (node:
    node.config.lab.vault-server.enable && node.config.networking.fqdn
    != config.networking.fqdn) (attrValues nodes);

  vaultKey = cmd: {
    user = "vault";
    group = "vault";
    permissions = "660";
    keyCommand = [ "vault-client" cmd "vault" ];
  };

in {
  options.lab.vault-server = {
    enable = mkEnableOption "Run a Vault server";
    tls.enable = mkOption {
      description = "Listen on HTTPS";
      type = types.bool;
      default = true;
    };

    settings = mkOption {
      description = "Generated config given to Vault";
      type = types.anything;
      default = { };
    };
  };

  config = mkIf cfg.enable {
    deployment.keys = {
      vault-role-id = vaultKey "role-id";
      vault-role-token = vaultKey "role-token";
    };

    environment.systemPackages = [ unstable.vault ];

    lab.vault-server.settings = {
      service_registration.consul.address = mkDefault "127.0.0.1:8500";
      cluster_addr = mkDefault "${scheme}://${localIp}:8201";
      api_addr = mkDefault "${scheme}://${localIp}:8200";

      listener.tcp = {
        address = mkDefault "0.0.0.0:8200";
      } // (if cfg.tls.enable then {
        tls_cert_file = mkDefault "/var/lib/vault/certs/tls.cert";
        tls_key_file = mkDefault "/var/lib/vault/certs/tls.key";
      } else {
        tls_disable = true;
      });

      storage.raft = {
        path = mkDefault
          config.systemd.services.vault.serviceConfig.WorkingDirectory;

        node_id = mkDefault config.networking.hostName;
      } // (optionalAttrs (length otherVaultServers > 0) {
        retry_join = mkDefault (forEach otherVaultServers (node: {
          leader_api_addr =
            "${scheme}://${node.config.lab.network.ipAddress}:8200";
        }));
      });
    };

    users.groups.vault.gid = config.ids.gids.vault;
    users.users.vault = {
      description = "Vault daemon user";
      extraGroups = [ "keys" ];
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

    lab.vault-agents.vault = {
      vault.address = "${scheme}://vault.service.${datacenter}.${domain}:8200";
      user = "root";
      group = "vault";
      templates = [
        {
          destination = "/var/lib/vault/certs/tls.cert";
          perms = "660";
          contents = ''
            {{
               with secret "pki/issue/vault"
                 "common_name=vault.service.${datacenter}.${domain}"
                 "alt_names=localhost"
                 "ip_sans=${localIp},127.0.0.1"
            }}
            {{ .Data.certificate }}{{ end }}
          '';
        }
        {
          command =
            "${pkgs.systemd}/bin/systemctl --no-block try-reload-or-restart vault.service";

          destination = "/var/lib/vault/certs/tls.key";
          perms = "660";
          contents = ''
            {{
               with secret "pki/issue/vault"
                 "common_name=vault.service.${datacenter}.${domain}"
                 "alt_names=localhost"
                 "ip_sans=${localIp},127.0.0.1"
            }}
            {{ .Data.private_key }}{{ end }}
          '';
        }
      ];

      extraSettings = {
        storage.inmem = { };
        auto_auth.method = [{
          type = "approle";
          config = {
            role_id_file_path = "/run/keys/vault-role-id";
            secret_id_file_path = "/run/keys/vault-role-token";
            secret_id_response_wrapping_path =
              "auth/approle/role/vault/secret-id";
          };
        }];
      };
    };
  };
}
