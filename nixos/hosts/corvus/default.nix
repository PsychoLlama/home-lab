{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

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

    wireless = {
      enable = true;
      interfaces = ["wlp6s0" "wlp7s0"];
    };
  };

  system.stateVersion = "21.05";
}