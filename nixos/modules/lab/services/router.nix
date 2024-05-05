{ config, lib, ... }:

with lib;

let
  inherit (config.lab) networks;
  cfg = config.lab.services.router;
in

{
  options.lab.services.router = {
    enable = mkEnableOption "Turn the device into a simple router";

    networks = mkOption {
      description = "Map of networks to create from `lab.networks`";
      default = { };
      type = types.attrsOf (
        types.submodule (
          { name, config, ... }:
          {
            options = {
              name = mkOption {
                description = "One of `lab.networks`";
                type = types.enum (attrNames networks);
                default = name;
              };

              interface = mkOption {
                description = "Name of the network interface to use";
                type = types.str;
              };

              # Aliases into `lab.networks` for convenience.
              ipv4 = mkOption {
                type = types.anything;
                default = networks.${config.name}.ipv4;
              };
            };
          }
        )
      );
    };

    wan.interface = mkOption {
      type = types.str;
      description = "WAN interface";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.lab.services.dns.enable;
        message = "To enable the router profile, DNS must also be enabled.";
      }
    ];

    networking = {
      useDHCP = false;

      # TODO: Generate this from `nodes`. There is no guarantee this machine
      # is the same one running a DNS server.
      nameservers = [ "127.0.0.1" ];

      interfaces = mkMerge [
        {
          # Get a public IP from the WAN link, presumably an ISP.
          ${cfg.wan.interface}.useDHCP = mkDefault true;
        }

        # Statically assign the gateway IP to all managed LAN interfaces.
        (mapAttrs' (_: network: {
          name = network.interface;
          value = {
            useDHCP = false;
            ipv4.addresses = [
              {
                address = network.ipv4.gateway;
                prefixLength = network.ipv4.prefixLength;
              }
            ];
          };
        }) cfg.networks)
      ];

      nat = {
        enable = true;
        externalInterface = cfg.wan.interface;
        internalInterfaces = mapAttrsToList (_: network: network.interface) cfg.networks;

        internalIPs = mapAttrsToList (
          _: network: "${network.ipv4.gateway}/${toString network.ipv4.prefixLength}"
        ) cfg.networks;
      };

      # Expose SSH to all LAN interfaces.
      firewall.interfaces = mapAttrs' (_: network: {
        name = network.interface;
        value.allowedTCPPorts = [ 22 ];
      }) cfg.networks;
    };

    lab.services.dhcp = {
      enable = true;
      networks = cfg.networks;
    };

    # SSH should not be accessible from the open internet.
    services.openssh.openFirewall = mkDefault false;

    # Enable strict reverse path filtering. This guards against some forms of
    # IP spoofing.
    boot.kernel.sysctl = mkMerge [
      {
        # Enable for the WAN interface.
        "net.ipv4.conf.default.rp_filter" = mkDefault 1;
        "net.ipv4.conf.${cfg.wan.interface}.rp_filter" = mkDefault 1;
      }

      # Enable for all LAN interfaces.
      (mapAttrs' (_: network: {
        name = "net.ipv4.conf.${network.interface}.rp_filter";
        value = mkDefault 1;
      }) cfg.networks)
    ];
  };
}
