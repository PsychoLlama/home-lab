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
in

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.self.nixosModules.nixos-platform
    inputs.agenix.nixosModules.default

    host.profile
    host.module
  ];

  # Deploy over Tailscale (MagicDNS resolves short hostnames)
  deployment.targetHost = config.networking.hostName;

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
        lab.stacks.host-defaults.enable = lib.mkDefault true;
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
  };

  users.defaultUserShell = home.programs.nushell.package;

  system = {
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or "dirty";

    # Flake inputs don't write .git-revision into the source tree, so the
    # defaults read by lib.trivial.revisionWithDefault return null and we end
    # up with "25.11pre-git" + "Nixpkgs commit hash is unknown". Set these
    # explicitly from the locked input.
    nixos = {
      revision = inputs.nixpkgs.rev or inputs.nixpkgs.dirtyRev or "dirty";
      versionSuffix =
        ".${builtins.substring 0 8 (inputs.nixpkgs.lastModifiedDate or "19700101")}"
        + ".${inputs.nixpkgs.shortRev or "dirty"}";
    };
  };
}
