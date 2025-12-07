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

  # Chunk a list into sublists of a specified size.
  #
  # chunkBy 2 [ 1 2 3 4 ] -> [ [ 1 2 ] [ 3 4 ] ]
  chunkBy =
    size: list:
    if list == [ ] then
      [ ]
    else
      [
        (lib.take size list)
      ]
      ++ chunkBy size (lib.drop size list);

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

      # Provide a stable MAC address to preserve the DHCP lease.
      interfaces.mv-primary.macAddress = lib.pipe config.networking.hostName [
        # Use the hostname hash to derive the MAC address.
        (builtins.hashString "md5")

        # [ "" "f" "0" .. "1" "e" "" ]
        (lib.splitString "")

        # [ "f" "0" .. "1" "e" ]
        (lib.filter (char: char != ""))

        # Take the first 12 characters (for a 6-byte MAC address).
        (lib.take 12)

        # [ 15 0 .. 1 14 ]
        (map lib.fromHexString)

        # Make sure the last bits of the first byte are `0b10` to indicate
        # a locally-administered unicast MAC address.
        (lib.imap0 (index: value: if index == 1 then lib.bitAnd (-2) (lib.bitOr value 2) else value))

        # [ "F" "2" .. "1" "E" ]
        (map lib.toHexString)

        # [ [ 15 2 ] .. [ 1 14 ] ]
        (chunkBy 2)

        # [ "F2" .. "1E" ]
        (lib.map (lib.concatStringsSep ""))

        # "F2:<...>:1E"
        (lib.concatStringsSep ":")
      ];
    };
  };

in

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.clapfile.nixosModules.nixos
    inputs.self.nixosModules.nixos-platform
    inputs.agenix.nixosModules.default

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
        lab.stacks.fancy-shell.enable = lib.mkDefault true;
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
