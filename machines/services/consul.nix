{ nodes, config, lib, pkgs, ... }:

with lib;

let
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
      consul-tls-cert = key ../../consul.cert;
      consul-tls-key = key ../../consul.key;
    };

    users.users.consul.extraGroups = [ "keys" ];
    services.consul = {
      enable = true;
      forceIpv4 = true;
      interface.bind = cfg.interface;
      package = unstable.consul;
      webUi = true;

      extraConfig = {
        inherit (import ../config.nix) domain datacenter;
        server = cfg.server.enable;
        connect.enabled = true;
        ports.grpc = 8502;
        retry_join = serverAddresses;
        addresses = {
          https = "0.0.0.0";
          dns = "0.0.0.0";
        };

        # This is the recommended port for HTTPS.
        ports.https = 8501;

        verify_incoming = true;
        verify_outgoing = true;
        verify_server_hostname = true;

        ca_file = "/etc/ssl/certs/home-lab.crt";
        cert_file = "/run/keys/consul-tls-cert";
        key_file = "/run/keys/consul-tls-key";
      } // (optionalAttrs cfg.server.enable {
        bootstrap_expect = length serverAddresses + 1;
      });
    };

    systemd.services.consul = {
      serviceConfig.SupplementaryGroups = [ "keys" ];
      after = [ "consul-tls-cert-key.service" "consul-tls-key-key.service" ];
      wants = [ "consul-tls-cert-key.service" "consul-tls-key-key.service" ];
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
  };
}
