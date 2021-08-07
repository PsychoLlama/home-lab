{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  nix = {
    distributedBuilds = true;
    buildMachines = [
      {
        hostName = "tron.selfhosted.city";
        sshUser = "root";
        system = "aarch64-linux";
      }
      {
        hostName = "clu.selfhosted.city";
        sshUser = "root";
        system = "aarch64-linux";
      }
    ];
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
      interfaces = [ "wlp6s0" "wlp7s0" ];
    };
  };

  services.nomad = {
    enable = true;
    enableDocker = true;
  };

  environment.systemPackages = [ pkgs.git pkgs.nixops pkgs.neovim ];

  services.container-orchestration.enable = true;
  services.service-mesh = {
    enable = true;
    iface = "wlp6s0";
  };

  system.stateVersion = "21.05";
}
