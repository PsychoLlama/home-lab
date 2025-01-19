# Creates a top-level NixOS config, applied to all machines in the home lab.
# This is responsible for setting the baseline configuration.
inputs: hostName: host:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.lab) domain datacenter;
  home = config.home-manager.users.root;

  # Proxy all network traffic through a macvlan interface. This allows the
  # host to communicate with containers using macvlans and vice versa.
  #
  # WARN: Shortly after enabling macvlan interfaces, a test deploy broke
  # networking since the macvlan was not available by the time dhcpcd started.
  # There seems to be a race.
  macvlan-proxy = {
    config.networking = lib.mkIf (config.lab.host.interface != null) {
      useDHCP = false;

      interfaces.mv-primary.useDHCP = true;
      macvlans.mv-primary = {
        mode = "bridge";
        interface = config.lab.host.interface;
      };
    };
  };

in

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.clapfile.nixosModules.nixos
    inputs.self.nixosModules.nixos-platform
    host.profile
    host.module
    macvlan-proxy
  ];

  deployment.targetHost = config.networking.fqdn;
  environment.sessionVariables.DATACENTER = datacenter;

  networking = {
    hostName = lib.mkDefault hostName;
    domain = "host.${datacenter}.${domain}";
  };

  nix = {
    # Run garbage collection on a schedule.
    gc.automatic = true;

    # Use hard links to save disk space.
    optimise.automatic = true;

    # Enable Flake support.
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  home-manager = {
    useGlobalPkgs = lib.mkDefault true;
    useUserPackages = lib.mkDefault true;
    sharedModules = [
      inputs.self.nixosModules.home-manager-platform

      {
        # Manage the system shell by default.
        lab.profiles.fancy-shell.enable = lib.mkDefault true;
      }
    ];
  };

  lab = {
    inherit host;

    ssh = {
      enable = lib.mkDefault true;
      authorizedKeys = [
        ./keys/deploy.pub
        ./keys/admin.pub
      ];
    };

    virtualisation.sharedModules = [
      # TODO: Add all platforms to the container namespace.
    ];
  };

  users.defaultUserShell = home.programs.nushell.package;
}
