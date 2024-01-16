{ config, lib, options, ... }:

with lib;

let cfg = config.lab.dhcp;

in {
  options.lab.dhcp = {
    enable = mkEnableOption "Run a DHCP server";
    networks = options.lab.router.networks;
    leases = options.services.dhcpd4.machines;
  };

  config = mkIf cfg.enable {
    # Open DHCP ports on participating LAN interfaces.
    networking.firewall.interfaces = mapAttrs' (_: network: {
      name = network.interface;
      value.allowedUDPPorts = [ 67 ];
    }) cfg.networks;

    # TODO: ... the rest ...
  };
}
