{ flake, lib, ... }:

let
  inherit (lib) types mkOption;

  networkOption =
    { config, name, ... }:
    let
      # WARN: `cidr` isn't set when evaluating documentation. Mark any derived
      # properties as `visible = false`.
      ipv4 = flake.lib.cidr.v4.parse config.ipv4.cidr;
    in
    {
      options.name = mkOption {
        type = types.str;
        default = name;
        description = ''
          Unique name of the network. Be careful changing it - some modules
          use it as persistent state.
        '';
      };

      options.ipv4 = {
        cidr = mkOption {
          description = ''
            Defines the subnet in CIDR notation. The IP address is the
            gatway.

            Syntax: "{gateway_ip}/{mask_bits}"

            Other fields are generated from this data for convenience.
          '';

          type = types.str;
          example = "192.168.1.1/24";
        };

        subnet = {
          cidr = mkOption {
            description = "The subnet in CIDR notation, without host bits";
            type = types.str;
            default = ipv4.subnet.cidr;
            example = "192.168.1.0/24";
            visible = false;
            readOnly = true;
          };

          mask = mkOption {
            description = "Subnet mask for this network";
            type = types.str;
            default = ipv4.subnet.mask;
            example = "255.255.255.0";
            visible = false;
            readOnly = true;
          };

          prefixLength = mkOption {
            description = "Number of bits in the network mask";
            type = types.int;
            default = ipv4.subnet.prefixLength;
            example = 24;
            visible = false;
            readOnly = true;
          };
        };

        addresses = {
          gateway = mkOption {
            description = "IP address of the gateway for this network";
            type = types.str;
            default = ipv4.addresses.host;
            example = "192.168.1.1";
            visible = false;
            readOnly = true;
          };

          network = mkOption {
            description = "Network address, the first in the subnet";
            type = types.str;
            default = ipv4.addresses.network;
            example = "192.168.1.0";
            visible = false;
            readOnly = true;
          };

          broadcast = mkOption {
            description = "Broadcast address for the network";
            type = types.str;
            default = ipv4.addresses.broadcast;
            example = "192.168.1.255";
            visible = false;
            readOnly = true;
          };
        };

        dhcp.pools = mkOption {
          description = "Assignable address ranges used by DHCP";
          default = [ ];
          type = types.listOf (
            types.submodule {
              options.start = mkOption {
                type = types.str;
                description = "Starting range for DHCP";
                example = "192.168.1.10";
              };

              options.end = mkOption {
                type = types.str;
                description = "Ending range for DHCP";
                example = "192.168.1.254";
              };
            }
          );
        };
      };
    };
in
{
  options.lab.networks = mkOption {
    description = ''
      A description of every network in the lab. This is used to generate
      subnets and routing rules in lower-level modules. It must be
      consistently defined for every host in the lab.
    '';

    type = types.attrsOf (types.submoduleWith { modules = [ networkOption ]; });
    default = { };
  };
}
