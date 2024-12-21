{ config, lib, ... }:

let
  inherit (lib) types mkOption;

  cfg = config.lab.services.gateway;

  # Enrich `cfg.networks` with data from `lab.networks`.
  networks = lib.mapAttrs (
    _: network: network // { inherit (config.lab.networks.${network.id}) ipv4; }
  ) cfg.networks;
in

{
  options.lab.services.gateway = {
    enable = lib.mkEnableOption "Run a NAT gateway and firewall";

    networks = mkOption {
      description = "Map of networks to create from `lab.networks`";
      default = { };
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              id = mkOption {
                description = "One of `lab.networks`";
                type = types.enum (lib.attrNames config.lab.networks);
                default = name;
              };

              interface = mkOption {
                description = "Name of the network interface to use";
                type = types.str;
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

  config = lib.mkIf cfg.enable {
    networking = {
      useDHCP = false;

      interfaces = lib.mkMerge [
        {
          # Get a public IP from the WAN link, presumably an ISP.
          ${cfg.wan.interface}.useDHCP = lib.mkDefault true;
        }

        # Statically assign the gateway IP to all managed LAN interfaces.
        (lib.mapAttrs' (_: network: {
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
        }) networks)
      ];

      nat = {
        enable = true;
        externalInterface = cfg.wan.interface;
        internalInterfaces = lib.mapAttrsToList (_: network: network.interface) networks;

        internalIPs = lib.mapAttrsToList (
          _: network: "${network.ipv4.gateway}/${toString network.ipv4.prefixLength}"
        ) networks;
      };

      # Expose SSH to all LAN interfaces.
      firewall.interfaces = lib.mapAttrs' (_: network: {
        name = network.interface;
        value.allowedTCPPorts = [ 22 ];
      }) networks;
    };

    # SSH should not be accessible from the open internet.
    services.openssh.openFirewall = lib.mkDefault false;

    # Enable strict reverse path filtering. This guards against some forms of
    # IP spoofing.
    boot.kernel.sysctl = lib.mkMerge [
      {
        # Enable for the WAN interface.
        "net.ipv4.conf.default.rp_filter" = lib.mkDefault 1;
        "net.ipv4.conf.${cfg.wan.interface}.rp_filter" = lib.mkDefault 1;
      }

      # Enable for all LAN interfaces.
      (lib.mapAttrs' (_: network: {
        name = "net.ipv4.conf.${network.interface}.rp_filter";
        value = lib.mkDefault 1;
      }) networks)
    ];
  };
}
