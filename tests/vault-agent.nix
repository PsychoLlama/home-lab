{ pkgs ? import ../machines/unstable-pkgs.nix { } }:

let
  vaultDevServer = {
    imports = [ ./services ];

    environment.systemPackages = [ pkgs.vault ];
    networking.firewall.allowedTCPPorts = [ 8200 ];
    systemd.services.vault-dev = {
      environment.VAULT_DEV_LISTEN_ADDRESS = "0.0.0.0:8200";
      description = "Vault server in development mode";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = [ pkgs.vault pkgs.getent ];
      script = ''
        exec vault server -dev -dev-root-token-id root
      '';
    };
  };

  vaultAgent = { config, ... }: {
    imports = [ ./services ];

    environment.variables = {
      VAULT_TOKEN = "root";
      VAULT_ADDR = "http://server:8200";
    };

    systemd.services.provision-credentials = {
      description = "Provision AppRole auth credentials";
      wantedBy = [ "multi-user.target" ];
      before = [ "vault-agent-test.service" ];
      path = [ pkgs.vault pkgs.jq pkgs.getent pkgs.curl ];
      environment = config.environment.variables;

      script = ''
        while ! curl "$VAULT_ADDR" --silent --output /dev/null; do
          echo 'Waiting for Vault...'
          sleep 1
        done

        vault policy write test -<<EOF
        $(vault policy read default)

        path "secret/*" {
          capabilities = ["read"]
        }
        EOF

        vault auth enable approle
        vault write auth/approle/role/test policies=test token_ttl=1h

        vault read -format=json auth/approle/role/test/role-id \
          | jq .data.role_id -r > /tmp/role-id

        vault write -force -format=json auth/approle/role/test/secret-id \
          | jq .data.secret_id -r > /tmp/secret-id
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    lab.vault-agents.test = {
      vault.address = config.environment.variables.VAULT_ADDR;
      extraSettings = {
        pid_file = "/tmp/vault-agent.pid";
        cache.use_auto_auth_token = true;
        storage.inmem = { };
        auto_auth = {
          method = [{
            type = "approle";

            config = {
              role_id_file_path = "/tmp/role-id";
              secret_id_file_path = "/tmp/secret-id";
            };
          }];
        };
      };
    };
  };

in {
  basic = pkgs.nixosTest {
    name = "vault-agent-basic";
    nodes = {
      server = vaultDevServer;
      agent = {
        imports = [ vaultAgent ];
        lab.vault-agents.test.templates = [{
          destination = "/tmp/vault-template-output";
          contents = ''
            {{ with secret "secret/message" }}{{ .Data.data.contents }}{{ end }}
          '';
        }];
      };
    };

    testScript = ''
      start_all()

      with subtest("Test connection to Vault"):
        server.wait_for_unit("vault-dev.service")
        server.wait_for_open_port(8200)
        agent.succeed("vault status")
        agent.succeed("vault token lookup")
        agent.succeed("vault kv put secret/message contents='hello world'")

      with subtest("Test agent startup"):
        agent.wait_for_unit("vault-agent-test.service")
        agent.wait_for_file("/tmp/vault-template-output")
        agent.succeed("grep 'hello world' /tmp/vault-template-output")
    '';
  };
}
