{
  config,
  pkgs,
  ...
}:

{
  home-manager.users.root.home.stateVersion = "23.11";
  system.stateVersion = "21.11";

  networking = {
    # Create bridge using physical interface
    macvlans.mv0 = {
      mode = "bridge";
      interface = "end0";
    };

    interfaces.mv0.useDHCP = true;
    firewall.allowedTCPPorts = [ 4444 ];
    # Bridge itself can use DHCP for host
    # interfaces.br0.useDHCP = true;
  };

  containers.test1 = {
    autoStart = true;
    privateNetwork = true;
    macvlans = [ "end0:bridge" ];

    config = {
      nixpkgs.pkgs = pkgs;
      system.stateVersion = config.system.stateVersion;

      networking = {
        # Container interface will get its own IP
        interfaces.bridge.useDHCP = true;
        firewall.allowedTCPPorts = [ 4444 ];
        hostName = "bacon";
      };

      services.openssh = {
        enable = true;
        settings.PasswordAuthentication = false;
      };

      users.users.root.openssh.authorizedKeys.keyFiles = [
        ../lib/keys/admin.pub
        ../lib/keys/deploy.pub
      ];
    };
  };
}
