{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) types;
  cfg = config.lab.virtualisation;

  # Generate a unique name that does not exceed the 15 character limit.
  mkIfname = name: "mv-${lib.substring 0 12 (builtins.hashString "md5" name)}";
in

{
  options.lab.virtualisation = {
    sharedModules = lib.mkOption {
      type = types.listOf types.deferredModule;
      default = [ ];
      description = ''
        Default NixOS modules to include in all containers.
      '';
    };

    containers = lib.mkOption {
      type = types.attrsOf types.deferredModule;
      default = { };

      description = ''
        Defines a set of NixOS Containers that start automatically.

        Because NixOS containers evaluate in a new blank NixOS namespace and
        there's no way to extend that namespace automatically, this provides
        a workaround by generating a module with all the imports and baseline
        configuration defined.

        The generated container uses macvlan networking to allow a private
        network namespace that can still communicate with the outside world.
        It assumes the host is also using macvlan networking, otherwise hosts
        and containers cannot communicate.

        WARNING: This does not work over WiFi because 802.11 only supports
        communicating with a single MAC address.
      '';
    };
  };

  config = {
    # Define host-level networking so the container can communicate with
    # the outside world.
    networking = lib.mkMerge (
      lib.mapAttrsToList (containerName: _: {
        interfaces.${mkIfname containerName}.useDHCP = lib.mkDefault true;

        macvlans.${mkIfname containerName} = {
          mode = "bridge";
          interface = lib.mkDefault config.lab.host.interface;
        };
      }) cfg.containers
    );

    containers = lib.mapAttrs (containerName: containerConfig: {
      autoStart = lib.mkDefault true;
      privateNetwork = lib.mkDefault true;

      macvlans = [
        "${config.lab.host.interface}:bridge"
      ];

      # The NixOS Containers implementation evaluates a whole new NixOS module
      # namespace for each container. This isn't a typical config.
      config = {
        imports = cfg.sharedModules ++ [ containerConfig ];

        config = {
          nixpkgs.pkgs = lib.mkDefault pkgs;
          system.stateVersion = lib.mkDefault config.system.stateVersion;

          networking = {
            useDHCP = false;
            hostName = lib.mkDefault containerName;
            interfaces.bridge.useDHCP = lib.mkDefault true;
          };
        };
      };
    }) cfg.containers;
  };
}
