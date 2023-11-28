{ lib, ... }:

{
  # A set of shared constants for the host. This is primarily used to
  # configure the network address and make it discoverable to other hosts.
  options.lab.host = with lib; {
    # TODO: Hard-code lab IPs instead of leasing from DHCP.
    ethernet = mkOption {
      type = types.str;
      example = "11:22:33:aa:bb:cc";
      description = "MAC address for the primary network interface";
    };

    ip4 = mkOption {
      type = types.str;
      example = "192.168.1.10";
      description = "IPv4 address for the primary network interface";
    };
  };
}
