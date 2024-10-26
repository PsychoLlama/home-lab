{ pkgs, config, ... }:

{
  home-manager.users.root.home.stateVersion = "23.11";
  system.stateVersion = "21.05";
  containers.test1 = {
    autoStart = true;
    privateNetwork = true;
    macvlans = [ "end0" ];
    config = {
      nixpkgs.pkgs = pkgs;
      system.stateVersion = config.system.stateVersion;

      networking = {
        interfaces."mv-end0".useDHCP = true;
        hostName = "container";
        firewall.allowedTCPPorts = [ 4444 ];
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

  containers.test2 = {
    autoStart = true;
    privateNetwork = true;
    macvlans = [ "end0" ];
    config = {
      nixpkgs.pkgs = pkgs;
      system.stateVersion = config.system.stateVersion;

      networking = {
        interfaces."mv-end0".useDHCP = true;
        hostName = "container";
        firewall.allowedTCPPorts = [ 4444 ];
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
