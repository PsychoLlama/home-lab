{ config, lib, ... }:

# Configuration folded into every machine in the lab. Colmena applies it as
# `defaults`; the VM tests apply it the same way.

let
  inherit (config.lab) datacenter domain tailnet;
in

{
  options.lab.defaults = lib.mkOption {
    type = lib.types.deferredModule;
    default = { };
    description = "NixOS configuration shared by every node.";
  };

  config.lab.defaults = {
    lab = {
      inherit datacenter domain tailnet;

      # Enable node exporter on all lab nodes for monitoring
      services.node-exporter.enable = true;

      networks = {
        datacenter.ipv4 = {
          cidr = "10.0.0.1/24";
          dhcp.pools = [
            {
              start = "10.0.0.10";
              end = "10.0.0.200";
            }
          ];
        };

        home.ipv4 = {
          cidr = "10.0.1.1/24";
          dhcp.pools = [
            {
              start = "10.0.1.10";
              end = "10.0.1.250";
            }
          ];
        };

        iot.ipv4 = {
          cidr = "10.0.2.1/24";
          dhcp.pools = [
            {
              start = "10.0.2.10";
              end = "10.0.2.250";
            }
          ];
        };

        work.ipv4 = {
          cidr = "10.0.3.1/24";
          dhcp.pools = [
            {
              start = "10.0.3.10";
              end = "10.0.3.250";
            }
          ];
        };

        guest.ipv4 = {
          cidr = "10.0.4.1/24";
          dhcp.pools = [
            {
              start = "10.0.4.10";
              end = "10.0.4.250";
            }
          ];
        };
      };
    };
  };
}
