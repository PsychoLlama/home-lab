{
  description = "Hobbyist home lab";
  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/22.11";
    hardware.url = "github:NixOS/nixos-hardware";
    flake-utils.url = "github:numtide/flake-utils";
    dns-blocklist = {
      url = "github:StevenBlack/hosts";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs-unstable, nixpkgs, hardware, flake-utils
    , dns-blocklist }:

    let
      defineHost = import ./machines/define-host.nix;
      hostDefinitions = with nixpkgs.lib;
        (mapAttrs (hostName: _: defineHost hostName)
          (filterAttrs (_: pathType: pathType == "directory")
            (builtins.readDir ./machines/hosts)));

      pkgs = import inputs.nixpkgs { system = "aarch64-linux"; };
      unstable = import inputs.nixpkgs-unstable { system = pkgs.system; };

    in {
      colmena = hostDefinitions // {
        meta = let inherit (import ./machines/config) domain;

        in rec {
          description = domain;

          nixpkgs = import inputs.nixpkgs { system = "aarch64-linux"; };

          # Pass flake inputs to all NixOS modules.
          specialArgs = {
            inherit inputs;

            unstable = import nixpkgs-unstable { system = nixpkgs.system; };
          };

          # TODO: Test `machinesFile` as an alternative way to configure
          # remote builders.
        };
      };
    } // flake-utils.lib.eachDefaultSystem (system:
      let unstable = import nixpkgs-unstable { inherit system; };

      in {
        checks = import ./tests { pkgs = unstable; };

        devShell = with unstable;
          mkShell {
            nativeBuildInputs = [
              (callPackage ./machines/pkgs/vault-client.nix { })
              vault
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
