{ config, lib, nodes, ... }:

with lib;

let
  # IP Addresses of nodes where `fn(node) == true`.
  addressesWhere = predicate:
    forEach (attrValues (filterAttrs (key: predicate) nodes))
    (node: node.config.lab.network.ipAddress);

  xbox-live-ports = {
    tcp = [ 3074 ];
    udp = [ 3074 3075 88 500 3544 4500 ];
  };

in {
  imports = [ ../../hardware/raspberry-pi-3.nix ];

  lab = {
    network = {
      ethernetAddress = "b8:27:eb:60:f5:88";
      ipAddress = "10.0.0.1";
    };

    router = {
      enable = true;
      debugging.enable = true;

      dns.services = [
        {
          name = "consul.service";
          addresses =
            addressesWhere (node: node.config.lab.consul.server.enable);
        }
        {
          name = "nomad.service";
          addresses =
            addressesWhere (node: node.config.lab.nomad.server.enable);
        }
        {
          name = "vault.service";
          addresses = addressesWhere (node: node.config.lab.vault.enable);
        }
      ];

      network = {
        lan.interface = "eth0"; # Native hardware
        wan.interface = "eth1"; # Dongle

        extraHosts = [{
          ethernetAddress = "98:5f:d3:14:0b:30";
          ipAddress = "10.0.0.250";
          hostName = "xbox-one";
        }];
      };
    };
  };

  # Although not technically part of the home lab, this is still my home
  # router and some networking requirements are bound to bleed over.
  #
  # This opens ports for multiplayer gaming on Xbox Live.
  networking = {
    nat.forwardPorts = forEach xbox-live-ports.tcp (port: {
      sourcePort = port;
      destination = "10.0.0.250:${builtins.toString port}";
      proto = "tcp";
    }) ++ forEach xbox-live-ports.udp (port: {
      sourcePort = port;
      destination = "10.0.0.250:${builtins.toString port}";
      proto = "udp";
    });

    firewall.interfaces.${config.lab.router.network.wan.interface} = {
      allowedUDPPorts = xbox-live-ports.udp;
      allowedTCPPorts = xbox-live-ports.tcp;
    };
  };

  system.stateVersion = "21.11";
}
