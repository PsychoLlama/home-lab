{ config, lib, pkgs, ... }:

with lib;

let
  mdns-interfaces = [ "vlan-iot" "wap" "vlan-guest" ];
  mdns-ports = [ 5353 ];

  xbox-ip-address = "10.0.2.250";
  xbox-live-ports = {
    tcp = [ 3074 ];
    udp = [ 3074 3075 88 500 3544 4500 ];
  };

in {
  imports = [ ../../modules/hardware/raspberry-pi-3.nix ];

  lab.network = {
    ethernetAddress = "b8:27:eb:60:f5:88";
    ipAddress = "10.0.0.203";
  };

  system.stateVersion = "21.11";
}
