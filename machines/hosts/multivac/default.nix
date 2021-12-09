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
  #   ssh-copy-id root@<worker>
  #
  services.openssh.hostKeys = [{
    type = "ed25519";
    path = "/root/.ssh/id_ed25519";
    comment = "NixOps deploy key";
  }];

  environment.systemPackages = with pkgs; [ nixopsUnstable neovim ];

  system.stateVersion = "21.05";
}
