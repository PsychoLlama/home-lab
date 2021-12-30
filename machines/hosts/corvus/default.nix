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

  system.stateVersion = "21.11";
}
