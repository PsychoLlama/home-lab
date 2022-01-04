{ config, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking = {
    useDHCP = false;
    interfaces = {
      enp4s0.useDHCP = true;
      enp5s0.useDHCP = true;
      enp8s0.useDHCP = true;
      wlp6s0.useDHCP = true;
      wlp7s0.useDHCP = true;
    };

    networkmanager.enable = true;
  };

  lab = {
    network = {
      ethernetAddress = "68:3e:26:c5:65:16";
      ipAddress = "10.0.0.205";
    };

    nomad.enable = true;
    consul = {
      server.enable = true;
      enable = true;
      iface = "wlp6s0";
    };
  };

  system.stateVersion = "21.11";
}
