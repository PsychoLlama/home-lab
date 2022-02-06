{ lib, config, pkgs, ... }:

let
  inherit (import ../config) domain;
  cfg = config.lab.vault-agents;
  generateConfig = agent:
    (pkgs.formats.json { }).generate "vault-agent-config.json" ({
      # NOTE: JSON configuration is slightly different from HCL. See here:
      # https://github.com/hashicorp/vault/issues/7380
      vault.address = agent.vault.address;
      template = agent.templates;
    } // agent.extraSettings);

in with lib; {
  options.lab.vault-agents = mkOption {
    description = "Vault clients used to generate template files";
    default = { };
    type = types.attrsOf (types.submodule {
      options.vault.address = mkOption {
        description = "The address of the vault server";
        type = types.str;
        default = "https://vault.service.lab.${domain}:8200";
      };

      options.user = mkOption {
        description = "UNIX user to execute the process under";
        type = types.str;
        default = "root";
      };

      options.group = mkOption {
        description = "UNIX group to execute the process under";
        type = types.str;
        default = "root";
      };

      options.extraSettings = mkOption {
        description = ''
          Extra settings to merge into Vault's config file.
          Use this to configure auto-auth.
        '';

        type = types.attrsOf types.anything;
        default = { };
      };

      options.templates = mkOption {
        default = [ ];
        type = types.listOf (types.submodule {
          options.source = mkOption {
            description = "Path to a Vault template";
            type = types.either types.str types.path;
            default = "";
          };

          options.contents = mkOption {
            description = "Inline Vault template string";
            type = types.str;
            default = "";
          };

          options.destination = mkOption {
            description = "Where to write the output";
            type = types.str;
          };

          options.command = mkOption {
            description = "Command to run after the template renders";
            type = types.str;
            default = "";
          };

          options.error_on_missing_key = mkOption {
            description = "Exit if the template breaks the schema";
            type = types.bool;
            default = true;
          };

          options.perms = mkOption {
            description = "Rendered file permissions";
            type = types.str;
            default = "0640";
          };
        });
      };
    });
  };

  config = {
    environment.systemPackages = [ pkgs.vault ];
    systemd.services = listToAttrs (attrValues (mapAttrs (serviceName: agent:
      nameValuePair "vault-agent-${serviceName}" {
        description = "Vault agent daemon";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        path = [ pkgs.getent ];
        script = ''
          exec ${pkgs.vault}/bin/vault agent \
            -config ${generateConfig agent}
        '';

        serviceConfig = {
          User = agent.user;
          Group = agent.group;
        };
      }) cfg));
  };
}
