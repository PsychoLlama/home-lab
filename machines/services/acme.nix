{ config, lib, pkgs, ... }:

let
  inherit (import ../config) domain contactEmail;
  unstable = import ../unstable-pkgs.nix { system = pkgs.system; };
  cfg = config.lab.acme;
  vaultClient = cmd: {
    user = "acme";
    group = "acme";
    permissions = "660";
    keyCommand = [ "vault-client" cmd "acme" ];
  };

in with lib; {
  options.lab.acme.enable = mkEnableOption "Request LetsEncrypt certificates";

  config = mkIf cfg.enable {
    deployment.keys = {
      acme-role-id = vaultClient "role-id";
      acme-role-token = vaultClient "role-token";
    };

    security.acme = {
      acceptTerms = true;
      email = contactEmail;

      certs.${domain} = {
        extraDomainNames = [ "*.${domain}" ];
        credentialsFile = "/run/keys/acme-env";
        dnsProvider = "cloudflare";

        # Bypass the router's response cache.
        dnsResolver = "1.1.1.1:53";

        postRun = ''
          export VAULT_TOKEN="$(< /run/keys/acme-vault-token)"

          for domain in /var/lib/acme/*; do
            cd "$domain" # This expands to an absolute path.

            ${unstable.vault}/bin/vault kv put \
              "secret/tls/$(basename "$domain")" \
              cert="@cert.pem" \
              key="@key.pem"
          done
        '';
      };
    };

    users.users.acme.extraGroups = [ "keys" ];
    systemd.services.${"acme-${domain}"} = {
      wants = [ "vault-agent-acme.service" ];
      after = [ "vault-agent-acme.service" ];
    };

    lab.vault-agents.acme = {
      group = "acme";

      # See ACME docs: https://go-acme.github.io/lego/dns/cloudflare/
      templates = [{
        destination = "/run/keys/acme-env";
        contents = ''
          {{ with secret "secret/acme/cloudflare-api" }}
          CF_DNS_API_TOKEN={{ .Data.data.token }}
          {{ end }}
        '';
      }];

      extraSettings.auto_auth = {
        method = [{
          type = "approle";
          config = {
            role_id_file_path = "/run/keys/acme-role-id";
            secret_id_file_path = "/run/keys/acme-role-token";
            secret_id_response_wrapping_path =
              "auth/approle/role/acme/secret-id";
          };
        }];

        sink = [{
          type = "file";
          config.path = "/run/keys/acme-vault-token";
        }];
      };
    };
  };
}
