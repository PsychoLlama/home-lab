{
  description = "Hobbyist home lab";
  inputs = {
    nixpkgs.url = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      defineHost = import ./machines/define-host.nix;
      hostDefinitions = with nixpkgs.lib;
        (mapAttrs (hostName: _: defineHost hostName)
          (filterAttrs (_: pathType: pathType == "directory")
            (builtins.readDir ./machines/hosts)));

    in {
      nixopsConfigurations = {
        default = hostDefinitions // {
          inherit nixpkgs;

          network = let inherit (import ./machines/config) domain;
          in {
            description = domain;
            enableRollback = true;
            storage.legacy.databasefile = "~/.nixops/deployments.nixops";
          };
        };
      };
    } // flake-utils.lib.eachDefaultSystem (system:
      let unstable = import ./machines/unstable-pkgs.nix { inherit system; };

      in {
        checks = import ./tests { pkgs = unstable; };

        devShell = with nixpkgs.legacyPackages.${system};
          mkShell {
            nativeBuildInputs = [
              (unstable.callPackage ./machines/pkgs/vault-client.nix { })
              unstable.vault

              nixopsUnstable
              nixUnstable
            ];

            # NOTE: Configuring remote builds through the client assumes you
            # are a trusted Nix user. Without permission, you'll see errors
            # where it refuses to compile a foreign architecture.
            NIX_CONFIG = ''
              experimental-features = nix-command flakes
              builders-use-substitutes = true
              builders = @${
                writeText "nix-remote-builders" ''
                  ssh://root@glados.host.selfhosted.city aarch64-linux /root/.ssh/nixops_deploy 4
                  ssh://root@tron.host.selfhosted.city aarch64-linux /root/.ssh/nixops_deploy 4
                  ssh://root@clu.host.selfhosted.city aarch64-linux /root/.ssh/nixops_deploy 4
                ''
              }
            '';

            shellHook = ''
              if [[ -z "$VAULT_TOKEN" ]]; then
                echo '--- Remember to set $VAULT_TOKEN ---' >&2
              fi
            '';
          };
      });
}
