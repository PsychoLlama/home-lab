{ nodes, config, lib, pkgs, ... }:

with lib;

let
  inherit (import ../config) domain datacenter;
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };
  cfg = config.lab.nomad;

  expectedServerCount = length (attrValues
    (filterAttrs (_: node: node.config.lab.nomad.server.enable) nodes));

  vaultKey = cmd: {
    user = "nomad";
    group = "nomad";
    permissions = "660";
    keyCommand = [ "vault-client" cmd "nomad" ];
  };

in {
  options.lab.nomad = {
    enable = mkEnableOption "Run Nomad as part of a cluster";
    server.enable = mkEnableOption "Orchestrate workloads for Nomad clients";
    client.enable = mkOption {
      type = types.bool;
      description = "Accept workloads from Nomad servers";
      default = true;
    };
  };

  config = mkIf cfg.enable {
    deployment.keys = {
      nomad-role-id = vaultKey "role-id";
      nomad-role-token = vaultKey "role-token";
    };

    # Without this, the Nomad CLI will attempt API calls over insecure HTTP.
    environment.variables.NOMAD_ADDR =
      "https://nomad.service.lab.selfhosted.city:4646";

    users.groups.nomad = { };
    users.users.nomad = {
      description = "Nomad agent daemon user";
      isSystemUser = true;
      group = "nomad";
      extraGroups = [ "keys" ];
    };

    services.nomad = {
      enable = true;
      package = unstable.nomad;

      # Provides network support for the Consul sidecar proxy.
      extraPackages = with unstable; [ cni-plugins consul ];
      dropPrivileges = cfg.client.enable == false;

      settings = {
        inherit (import ../config) datacenter;

        server = {
          enabled = cfg.server.enable;
          bootstrap_expect = expectedServerCount;
        };

        client = {
          enabled = cfg.client.enable;
          cni_path = "${unstable.cni-plugins}/bin";
          servers = [ "nomad.service.lab.selfhosted.city" ];

          # Force downgrade Envoy. See:
          # https://github.com/envoyproxy/envoy/issues/15235
          meta = { "connect.sidecar_image" = "envoyproxy/envoy:v1.16.4"; };
        };

        consul = {
          address = "127.0.0.1:8501";
          grpc_address = "127.0.0.1:8502";
          ssl = true;

          ca_file = "/etc/ssl/certs/home-lab.crt";
          cert_file = "/var/lib/nomad/certs/tls.cert";
          key_file = "/var/lib/nomad/certs/tls.key";
        };

        tls = {
          rpc = true;
          http = true;

          ca_file = "/etc/ssl/certs/home-lab.crt";
          cert_file = "/var/lib/nomad/certs/tls.cert";
          key_file = "/var/lib/nomad/certs/tls.key";
        };
      };
    };

    systemd.services.nomad = {
      after = [ "vault-agent-nomad.service" "consul.service" ];
      wants = [ "vault-agent-nomad.service" "consul.service" ];
    };

    networking.firewall = {
      allowedTCPPorts = [
        4646 # HTTP API
        4647 # Private RPC
        4648 # Serf WAN
      ];

      allowedUDPPorts = [
        4648 # Serf WAN
      ];

      # Dynamic port allocations
      allowedTCPPortRanges = [{
        from = 20000;
        to = 32000;
      }];

      # Dynamic port allocations
      allowedUDPPortRanges = [{
        from = 20000;
        to = 32000;
      }];
    };

    # Nomad tightly integrates with Consul and strongly discourages use over
    # the network; It must run locally.
    lab.consul.enable = mkDefault cfg.client.enable;

    systemd.services.vault-agent-nomad = {
      after = [ "nomad-role-id-key.service" "nomad-role-token-key.service" ];
      wants = [ "nomad-role-id-key.service" "nomad-role-token-key.service" ];
    };

    lab.vault-agents.nomad = {
      vault.address = "https://vault.service.${datacenter}.${domain}:8200";
      user = "root";
      group = "nomad";
      templates = [
        {
          destination = "/var/lib/nomad/certs/tls.cert";
          perms = "660";
          contents = ''
            {{ with secret "pki/issue/nomad" "common_name=nomad.service.${datacenter}.${domain}" }}
            {{ .Data.certificate }}{{ end }}
          '';
        }
        {
          command =
            "${pkgs.systemd}/bin/systemctl --no-block try-reload-or-restart nomad.service";

          destination = "/var/lib/nomad/certs/tls.key";
          perms = "660";
          contents = ''
            {{ with secret "pki/issue/nomad" "common_name=nomad.service.${datacenter}.${domain}" }}
            {{ .Data.private_key }}{{ end }}
          '';
        }
      ];

      extraSettings = {
        storage.inmem = { };
        auto_auth.method = [{
          type = "approle";
          config = {
            role_id_file_path = "/run/keys/nomad-role-id";
            secret_id_file_path = "/run/keys/nomad-role-token";
            secret_id_response_wrapping_path =
              "auth/approle/role/nomad/secret-id";
          };
        }];
      };
    };
  };
}
