{ config, ... }:

{
  lab.hosts.rpi4-002 = {
    profile = config.lab.deviceProfiles.raspberry-pi-4;
    system = "aarch64-linux";
    ip4 = "10.0.0.208";
    interface = "end0";
    publicKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJLMZ6+HaPahE4gGIAWW/uGIl/y40p/rSfIhb5t4G+g9" ];

    module = {
      lab.services.ntfy = {
        enable = true;
        prometheus.enable = true;
      };

      lab.stacks = {
        home-automation.enable = true;
        observability.enable = true;
        vpn.client = {
          enable = true;
          exitNode = true;
        };
      };

      home-manager.users.root.home.stateVersion = "23.11";
      system.stateVersion = "21.11";
    };
  };
}
