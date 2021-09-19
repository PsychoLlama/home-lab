{ pkgs, ... }:

{
  imports = [ ../../hardware/raspberry-pi-3.nix ];

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
      {
        hostName = "corvus";
        sshUser = "root";
        system = "x86_64-linux";
      }
    ];
  };

  # BOOTSTRAP PROCESS: Initialize this machine then copy the key to every
  # worker node.
  #
  #   nixops deploy --include cluster-manager
  #   ssh-copy-id -i /root/.ssh/deploy_key root@<worker>
  #
  services.openssh.hostKeys = [{
    type = "ed25519";
    path = "/root/.ssh/deploy_key";
    comment = "NixOps deploy key";
  }];

  environment.systemPackages = with pkgs; [ git nixops neovim ];

  system.stateVersion = "21.05";
}
