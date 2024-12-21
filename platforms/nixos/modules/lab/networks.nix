{ pkgs, lib, ... }:

let
  inherit (lib) types mkOption;

  buildCidrInfo = pkgs.writers.writePython3 "print_cidr_info" { } ''
    from ipaddress import ip_interface
    import sys
    import json

    # Expects a CIDR address as the first argument.
    interface = ip_interface(sys.argv[1])
    data = json.dumps({
        "gatewayAddress": str(interface.ip),
        "networkAddress": str(interface.network.network_address),
        "broadcastAddress": str(interface.network.broadcast_address),
        "prefixLength": interface.network.prefixlen,
        "subnetMask": str(interface.network.netmask),
        "subnet": str(interface.network),
    })

    print(data)
  '';

  # Run the python script passing the CIDR address. Read the file back as
  # JSON, providing the data as a Nix value.
  parseCidrNotation =
    cidr_address:
    builtins.fromJSON (
      builtins.readFile (
        pkgs.runCommand "cidr-info" { inherit cidr_address; } ''
          ${buildCidrInfo} $cidr_address > $out
        ''
      )
    );

  networkOption =
    { config, ... }:
    let
      # WARN: `cidr` isn't set when evaluating documentation. Mark any derived
      # properties as `visible = false`.
      ipv4 = parseCidrNotation config.ipv4.cidr;
    in
    {
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

        gateway = mkOption {
          description = "IP address of the gateway for this network";
          type = types.str;
          default = ipv4.gatewayAddress;
          example = "192.168.1.1";
          visible = false;
          readOnly = true;
        };

        network = mkOption {
          description = "First available IP address in the network";
          type = types.str;
          default = ipv4.networkAddress;
          example = "192.168.1.0";
          visible = false;
          readOnly = true;
        };

        broadcast = mkOption {
          description = "Broadcast address for the network";
          type = types.str;
          default = ipv4.broadcastAddress;
          example = "192.168.1.255";
          visible = false;
          readOnly = true;
        };

        prefixLength = mkOption {
          description = "Number of bits in the network mask";
          type = types.int;
          default = ipv4.prefixLength;
          example = 24;
          visible = false;
          readOnly = true;
        };

        netmask = mkOption {
          description = "Subnet mask for this network";
          type = types.str;
          default = ipv4.subnetMask;
          example = "255.255.255.0";
          visible = false;
          readOnly = true;
        };

        subnet = mkOption {
          description = "CIDR notation of the subnet";
          type = types.str;
          default = ipv4.subnet;
          example = "192.168.1.0/24";
          visible = false;
          readOnly = true;
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
