{ lib, config, ... }:

let cfg = config.deployment.keys;

in with lib; {
  options.deployment.keys = mkOption {
    description = "Mounted secrets";
    default = { };
    type = types.attrsOf (types.submodule {
      options = {
        user = mkOption {
          type = types.str;
          default = "root";
        };

        group = mkOption {
          type = types.str;
          default = "root";
        };

        permissions = mkOption {
          type = types.str;
          default = "660";
        };

        text = mkOption {
          description = "Secret content";
          type = types.str;
        };
      };
    });
  };

  config = {
    systemd.services = listToAttrs (mapAttrsToList (keyName: _:
      nameValuePair "${keyName}-key" {
        description = "Fake deployment key";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      }) cfg);
  };
}
