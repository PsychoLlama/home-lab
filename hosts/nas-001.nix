{
  lab.stacks = {
    vpn.client = {
      enable = true;
      tags = [ "nas" ];
    };
    file-server.enable = true;
  };

  home-manager.users.root.home.stateVersion = "25.05";
  system.stateVersion = "25.05";
}
