{ config, ... }:

let
  inherit (config.lab.services.router.networks) datacenter home;
  inherit (config.lab.services.router) wan;

in {
  lab.profiles.router.enable = true;

  # Assign sensible names to the network interfaces. Anything with vlans needs
  # a hardware-related filter to avoid conflicts with virtual devices.
  services.udev.extraRules = ''
    SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="b0:a7:b9:2c:a9:b5", NAME="${home.interface}", ENV{ID_BUS}=="usb"
    SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="dc:a6:32:e1:42:81", NAME="${datacenter.interface}"
    SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="60:a4:b7:59:07:f2", NAME="${wan.interface}"
  '';

  system.stateVersion = "21.05";
}
