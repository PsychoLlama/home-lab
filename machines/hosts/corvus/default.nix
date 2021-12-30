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
    container-orchestration.enable = true;
    service-mesh = {
      enable = true;
      iface = "wlp6s0";
    };
  };

  system.stateVersion = "21.11";
}
