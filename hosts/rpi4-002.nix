{
  lab.stacks = {
    home-automation.enable = true;
    observability.enable = true;
    vpn.client.enable = true;
  };

  home-manager.users.root.home.stateVersion = "23.11";
  system.stateVersion = "21.11";
}
