{
  lab.stacks.ingress = {
    enable = true;
    virtualHosts.grafana = {
      serverName = "grafana.selfhosted.city";
      backend = "rpi4-002:3000";
    };

    virtualHosts.syncthing = {
      serverName = "syncthing.selfhosted.city";
      backend = "nas-001:8384";
    };

    virtualHosts.restic = {
      serverName = "restic.selfhosted.city";
      backend = "nas-001:8000";
    };

    virtualHosts.home = {
      serverName = "home.selfhosted.city";
      backend = "rpi4-002:8123";
    };
  };

  home-manager.users.root.home.stateVersion = "23.11";
  system.stateVersion = "21.05";
}
