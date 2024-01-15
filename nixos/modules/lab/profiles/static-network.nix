{ config, lib, ... }:

# This module statically configures the network instead of pulling it from
# DHCP. It's a temporary (?) module to keep things stable while I swap the
# DHCP server.

with lib;

let
  cfg = config.lab.static-network;
  network = config.lab.networks.datacenter;

in {
  options.lab.static-network = {
    enable = mkEnableOption "Manually configure the network";
    interface = mkOption {
      type = types.str;
      description = "Interface name connected to the datacenter network";
    };
  };

  config.networking = mkIf cfg.enable {
    nameservers = network.ipv4.nameservers;

    defaultGateway = {
      address = network.ipv4.gateway;
      interface = cfg.interface;
    };

    interfaces.${cfg.interface} = {
      useDHCP = false;

      ipv4.addresses = [{
        address = config.lab.host.ip4;
        prefixLength = network.ipv4.prefixLength;
      }];
    };
  };
}
