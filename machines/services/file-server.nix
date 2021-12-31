{ pkgs, lib, config, options, ... }:

# Turns the device into a simple file server.

let
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };
  cfg = config.lab.file-server;

in with lib; {
  options.lab.file-server = {
    enable = mkEnableOption "Act as a file server";
    hostId = options.networking.hostId;

    pools = mkOption {
      type = types.listOf types.str;
      description = ''
        Manages ZFS pools.
        Note: initialize them manually before you list them here.
      '';

      default = [ ];
    };

    mounts = mkOption {
      type = types.attrsOf types.str;

      description = ''
        Filesystem mounts for ZFS. Keys are file paths, values are datasets.
      '';

      example = { "/mnt/data" = "tank/data"; };

      default = { };
    };
  };

  config = mkIf cfg.enable {
    networking.hostId = cfg.hostId;

    boot = {
      supportedFilesystems = [ "zfs" ];
      zfs.requestEncryptionCredentials = cfg.pools;
    };

    services.zfs = {
      trim.enable = mkDefault true;

      autoSnapshot = {
        enable = mkDefault true;
        flags = mkDefault "-kp --utc";
      };

      autoScrub = {
        enable = mkDefault true;
        pools = mkDefault cfg.pools;
      };
    };

    fileSystems = mapAttrs (filePath: dataset: {
      device = dataset;
      fsType = "zfs";
      options = [ "zfsutil" ];
    }) cfg.mounts;
  };
}
