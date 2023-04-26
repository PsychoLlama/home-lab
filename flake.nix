{
  description = "Hobbyist home lab";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/22.11";
    flake-utils.url = "github:numtide/flake-utils";
    dns-blocklist = {
      url = "github:StevenBlack/hosts";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, dns-blocklist }:
    let
      defineHost = import ./machines/define-host.nix;
      hostDefinitions = with nixpkgs.lib;
        (mapAttrs (hostName: _: defineHost hostName)
          (filterAttrs (_: pathType: pathType == "directory")
            (builtins.readDir ./machines/hosts)));

    in {
      colmena = hostDefinitions // {
        meta = let inherit (import ./machines/config) domain;
        in {
          nixpkgs = import nixpkgs { system = "aarch64-linux"; };

          # TODO: Test `machinesFile` as an alternative way to configure
          # remote builders.

          description = domain;
        };

        # Pass flake inputs to all NixOS modules.
        defaults._module.args.inputs = inputs;
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
              nixUnstable
              colmena
            ];

            # NOTE: Configuring remote builds through the client assumes you
            # are a trusted Nix user. Without permission, you'll see errors
            # where it refuses to compile a foreign architecture.
            NIX_CONFIG = ''
              experimental-features = nix-command flakes
              builders-use-substitutes = true
              builders = @${
                writeText "nix-remote-builders" ''
                  ssh://root@glados.host.selfhosted.city aarch64-linux /root/.ssh/home_lab 4
                  ssh://root@tron.host.selfhosted.city aarch64-linux /root/.ssh/home_lab 4
                  ssh://root@clu.host.selfhosted.city aarch64-linux /root/.ssh/home_lab 4
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
