{ config, ... }:

{
  lab.hosts.rpi4-003 = {
    profile = config.lab.deviceProfiles.raspberry-pi-4;
    system = "aarch64-linux";
    ip4 = "10.0.0.204";
    interface = "end0";
    publicKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFsNbo3bbm0G11GAbRwnr944AitRyqoQMN4LG7rMsvpK" ];

    module = {
      lab.stacks.ingress = {
        private.enable = true;
        public.enable = true;
      };

      home-manager.users.root.home.stateVersion = "23.11";
      system.stateVersion = "21.05";
    };
  };
}
