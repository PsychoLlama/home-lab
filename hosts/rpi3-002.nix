{
  lab.profiles = {
    vpn.client.enable = true;

    # File server is temporarily disabled. 2/3 drives corrupted.
    # I'm a terrible sysadmin.
    file-server.enable = false;
  };

  networking.hostId = "e3cda066"; # Required by ZFS

  home-manager.users.root.home.stateVersion = "23.11";
  system.stateVersion = "23.05";
}
