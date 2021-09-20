{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  nix = {
    distributedBuilds = true;
    buildMachines = [
      {
        hostName = "tron";
        sshUser = "root";
        system = "aarch64-linux";
      }
      {
        hostName = "clu";
        sshUser = "root";
        system = "aarch64-linux";
      }
    ];
  };

  # BOOTSTRAP PROCESS: Initialize this machine then copy the key to every
  # worker node.
  #
  #   nixops deploy --include cluster-manager
  #   ssh-copy-id -i /root/.ssh/id_ed25519.pub root@<worker>
  #
  services.openssh.hostKeys = [{
    type = "ed25519";
    path = "/root/.ssh/id_ed25519";
    comment = "NixOps deploy key";
  }];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    grub.enable = true;
    grub.version = 2;
    grub.device = "/dev/sdb";
  };

  networking = {
    useDHCP = false;
    interfaces = {
      eno1.useDHCP = true;
      eno2.useDHCP = true;
      eno3.useDHCP = true;
      eno4.useDHCP = true;
    };
  };

  services.nomad = {
    enable = true;
    enableDocker = true;
  };

  environment.systemPackages = with pkgs; [ git nixops neovim ];

  services.container-orchestration.enable = true;
  services.service-mesh = { enable = true; iface = "eno4"; };

  system.stateVersion = "21.05";
}
