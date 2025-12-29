{
  lab.stacks.ingress = {
    enable = true;
    virtualHosts.grafana = {
      serverName = "grafana.selfhosted.city";
      backend = "rpi4-002:3000";
      targetTag = "monitoring";
    };

    virtualHosts.syncthing = {
      serverName = "syncthing.selfhosted.city";
      backend = "nas-001:8384";
      targetTag = "nas";
    };

    virtualHosts.restic = {
      serverName = "restic.selfhosted.city";
      backend = "nas-001:8000";
      targetTag = "nas";
    };

    virtualHosts.home = {
      serverName = "home.selfhosted.city";
      backend = "rpi4-002:8123";
      targetTag = "home-automation";
    };

    virtualHosts.unifi = {
      serverName = "unifi.selfhosted.city";
      backend = "https://rpi4-001:8443";
      targetTag = "router";
      insecure = true;
    };

    virtualHosts.ntfy = {
      serverName = "ntfy.selfhosted.city";
      backend = "rpi4-002:2586";
      targetTag = "ntfy";
    };
  };

  home-manager.users.root.home.stateVersion = "23.11";
  system.stateVersion = "21.05";
}
