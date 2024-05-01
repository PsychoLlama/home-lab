{
  lab.profiles.file-server.enable = true;
  networking.hostId = "e3cda066"; # Required by ZFS

  home-manager.users.root.home.stateVersion = "23.11";
  system.stateVersion = "23.05";
}
