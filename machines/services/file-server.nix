{ pkgs, lib, config, options, ... }:

# Turns the device into a simple file server.

let
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };
  cfg = config.lab.file-server;
  poolNames = pools: lib.forEach pools (pool: pool.name);

in with lib; {
  options.lab.file-server = {
    enable = mkEnableOption "Act as a file server";
    hostId = options.networking.hostId;

    pools = mkOption {
      type = types.listOf (types.submodule {
        options.name = mkOption {
          type = types.str;
          description = "The name of the ZFS pool";
          example = "tank";
        };
      });

      description = ''
        Manages ZFS pools.
        Note: initialize them manually before you list them here.
      '';

      default = [ ];
    };
  };

  config = mkIf cfg.enable {
    boot.supportedFilesystems = [ "zfs" ];
    networking.hostId = cfg.hostId;

    boot.zfs = mkIf (length cfg.pools > 0) {
      extraPools = poolNames cfg.pools;
      requestEncryptionCredentials = forEach cfg.pools (pool: pool.name);
    };

    boot.initrd.network = mkIf (length cfg.pools > 0) {
      enable = true;
      ssh = {
        enable = true;
        port = 2222;
        hostKeys = [ "/etc/secrets/initrd/id_ed25519" ];
        authorizedKeys = [ (builtins.readFile ../keys/admin.pub) ];
      };

      postCommands = ''
        cat > /root/.profile <<EOF
        if pgrep --exact zfs > /dev/null; then
          # Recursively decrypt all managed pools.
          zfs load-key -r ${concatStringsSep " " (poolNames cfg.pools)}

          # Terminate the other prompt started by the boot loader.
          killall zfs
        else
          echo "No other decryption job is running." > /dev/stderr
        fi
        EOF
      '';
    };
  };
}
