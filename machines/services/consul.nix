{ nodes, config, lib, pkgs, ... }:

with lib;

let
  inherit (import ../config) domain datacenter;
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };
  cfg = config.lab.consul;

  serverAddresses = filter (fqdn: fqdn != config.networking.fqdn)
    (mapAttrsToList (_: node: node.config.networking.fqdn)
      (filterAttrs (_: node: node.config.lab.consul.server.enable) nodes));

  key = file: {
    user = "consul";
    group = "consul";
    permissions = "440";
    text = builtins.readFile file;
  };

  vaultKey = cmd: {
    user = "consul";
    group = "consul";
    permissions = "660";
    keyCommand = [ "vault-client" cmd "consul" ];
  };

in {
  options.lab.consul = {
    enable = mkEnableOption "Run Consul as part of a cluster";
    interface = mkOption {
      type = types.str;
      default = "eth0";
      description = "Which network interface to bind to";
    };

    server.enable = mkEnableOption "Run Consul in server mode";
  };

  config = mkIf cfg.enable {
    deployment.keys = {
      consul-role-id = vaultKey "role-id";
      consul-role-token = vaultKey "role-token";
    };

    users.users.consul.extraGroups = [ "keys" ];
    services.consul = {
      enable = true;
      forceIpv4 = true;
      interface.bind = cfg.interface;
      package = unstable.consul;
      webUi = true;

      extraConfig = {
        inherit (import ../config) domain datacenter;
        server = cfg.server.enable;
        retry_join = serverAddresses;
        connect.enabled = true;

        addresses = {
          https = "0.0.0.0";
          dns = "0.0.0.0";
        };

        ports = {
          https = 8501;
          grpc = 8502;
        };

        verify_incoming = true;
        verify_outgoing = true;
        verify_server_hostname = true;

        ca_file = "/etc/ssl/certs/home-lab.crt";
        cert_file = "/var/lib/consul/certs/tls.cert";
        key_file = "/var/lib/consul/certs/tls.key";
      } // (optionalAttrs cfg.server.enable {
        bootstrap_expect = length serverAddresses + 1;
      });
    };

    systemd.services.consul = {
      after = [ "vault-agent-consul.service" ];
      wants = [ "vault-agent-consul.service" ];
    };

    networking.firewall = {
      allowedTCPPorts = [
        8600 # DNS
        8501 # HTTPS API
        8502 # gRPC API
        8300 # Server-to-server RPC
        8301 # LAN Serf
        8302 # WAN Serf
      ];

      allowedUDPPorts = [
        8600 # DNS
        8301 # LAN Serf
        8302 # WAN Serf
      ];

      # Sidecar proxy
      allowedTCPPortRanges = [{
        from = 21000;
        to = 21255;
      }];
    };

    systemd.services.vault-agent-consul = {
      after = [ "consul-role-id-key.service" "consul-role-token-key.service" ];
      wants = [ "consul-role-id-key.service" "consul-role-token-key.service" ];
    };

    lab.vault-agents.consul = {
      user = "root";
      group = "consul";
      templates = [
        {
          destination = "/var/lib/consul/certs/tls.cert";
          contents = ''
            {{
               with secret "pki/issue/consul"
                 "common_name=consul.service.${datacenter}.${domain}"
                 "alt_names=server.${datacenter}.${domain}"
                 "ip_sans=${config.lab.network.ipAddress},127.0.0.1"
            }}
            {{ .Data.certificate }}{{ end }}
          '';
        }
        {
          command =
            "${pkgs.systemd}/bin/systemctl --no-block try-reload-or-restart consul.service";

          destination = "/var/lib/consul/certs/tls.key";
          contents = ''
            {{
               with secret "pki/issue/consul"
                 "common_name=consul.service.${datacenter}.${domain}"
                 "alt_names=server.${datacenter}.${domain}"
                 "ip_sans=${config.lab.network.ipAddress},127.0.0.1"
            }}
            {{ .Data.private_key }}{{ end }}
          '';
        }
      ];

      extraSettings.auto_auth.method = [{
        type = "approle";
        config = {
          role_id_file_path = "/run/keys/consul-role-id";
          secret_id_file_path = "/run/keys/consul-role-token";
          secret_id_response_wrapping_path =
            "auth/approle/role/consul/secret-id";
        };
      }];
    };
  };
}
