{ pkgs ? import ../machines/unstable-pkgs.nix { } }:

let
  vaultServer = { config, ... }: {
    imports = [ ./services ];
    environment.variables.VAULT_ADDR = "http://127.0.0.1:8200";
    networking.domain = "lan";

    networking.firewall = {
      allowedTCPPorts = [ 8600 8500 8502 8300 8301 ];
      allowedUDPPorts = [ 8600 8301 ];
    };

    # Not technically correct, but whatever.
    lab.network.ipAddress = config.networking.fqdn;
    systemd.services.vault-agent-vault.enable = false;

    lab.vault-server = {
      enable = true;
      tls.enable = false;
    };

    services.consul = {
      enable = true;
      interface.bind = "eth1";
      extraConfig = {
        retry_interval = "1s";
        retry_join = [ "consul" ];
      };
    };
  };

  consulServer = {
    imports = [ ./services ];
    environment.systemPackages = [ pkgs.dogdns ];

    networking.firewall = {
      allowedTCPPorts = [ 8600 8500 8502 8300 8301 ];
      allowedUDPPorts = [ 8600 8301 ];
    };

    services.consul = {
      enable = true;
      interface.bind = "eth1";
      extraConfig = {
        server = true;
        bootstrap_expect = 1;
        addresses = {
          http = "0.0.0.0";
          dns = "0.0.0.0";
        };
      };
    };
  };

  vaultInitializer = { nodes, config, lib, ... }:
    with lib; {
      systemd.services.initialize-vault = {
        description = "Initialize Vault";
        wantedBy = [ "multi-user.target" ];
        after = [ "vault.service" ];
        path = [ pkgs.vault pkgs.jq pkgs.getent pkgs.curl ];
        environment = config.environment.variables;

        script = ''
          set -euo pipefail

          while ! curl "$VAULT_ADDR" --silent --output /dev/null; do
            echo 'Waiting for Vault...'
            sleep 1
          done

          output="$(vault operator init -format=json -key-shares=1 -key-threshold=1)"
          unseal_key="$(echo "$output" | jq -r ".unseal_keys_b64[0]")"
          vault operator unseal "$unseal_key"

          # For later use.
          echo "$output" | jq -r ".root_token" > /tmp/vault-root-token
          echo "$unseal_key" > /tmp/vault-unseal-key
        '';

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };
    };

in {
  full = pkgs.nixosTest {
    name = "vault-server-full";

    nodes = {
      vault1 = {
        imports = [ vaultServer vaultInitializer ];
        environment.etc."vault/recovery.json".text = ''
          [{
            "id": "vault1",
            "address": "vault1.lan:8201",
            "non_voter": false
          }]
        '';
      };

      vault2 = vaultServer;
      consul = consulServer;
    };

    testScript = ''
      start_all()

      consul.wait_for_unit("consul.service")
      consul.wait_for_open_port(8500)
      unseal_key = None

      with subtest("Test Vault initialization"):
        vault1.wait_for_unit("initialize-vault.service")
        unseal_key = vault1.succeed("cat /tmp/vault-unseal-key")

        # This only works once Raft replication kicks into gear.
        vault2.wait_until_succeeds(f"vault operator unseal {unseal_key}")

      with subtest("Test service discovery"):
        # Wait until the Consul cluster is ready.
        vault1.wait_until_succeeds("consul kv put hello/world content")
        vault2.wait_until_succeeds("consul kv put hello/world content")

        consul.wait_until_succeeds("dog @localhost:8600 active.vault.service.consul | grep vault1.lan")
        consul.wait_until_succeeds("dog @localhost:8600 standby.vault.service.consul | grep vault2.lan")

      with subtest("Test Vault replication"):
        token = vault1.succeed("cat /tmp/vault-root-token")
        vault1.succeed(f"vault login {token}")
        vault2.succeed(f"vault login {token}")

        vault1.succeed("vault secrets enable kv")
        vault1.succeed("vault kv put kv/data contents=hello")
        vault2.succeed("vault kv get kv/data | grep hello")

      # If the lab goes offline for too long, the Vault certificates will
      # expire and manual intervention is necessary. This test ensures it's
      # possible to recover the cluster.
      with subtest("Test manual recovery after network partition"):
        vault1.block()

        vault1.succeed("cp /etc/vault/recovery.json /var/lib/vault/raft/peers.json")
        vault1.systemctl("restart vault")
        vault1.wait_for_open_port(8200)

        vault1.succeed(f"vault operator unseal {unseal_key}")
        vault1.wait_until_succeeds("vault kv get kv/data | grep hello")
    '';
  };
}
