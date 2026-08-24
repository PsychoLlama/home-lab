{ config, ... }:

{
  lab.hosts.nas-001 = {
    profile = config.lab.deviceProfiles.cm3588;
    system = "aarch64-linux";
    ip4 = "10.0.0.15";
    interface = "enP4p65s0";
    publicKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOx6MIH8pVfBi0dckuIgssJO5JzlnEKrJrhNSPs7giTR" ];

    module = {
      lab.stacks = {
        vpn.client.enable = true;
        file-server.enable = true;
      };

      home-manager.users.root.home.stateVersion = "25.05";
      system.stateVersion = "25.05";
    };
  };
}
