{
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
}
