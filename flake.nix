{
  description = "Hobbyist home lab";

  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    colmena = {
      url = "github:zhaofengli/colmena";
      inputs = {
        nixpkgs.follows = "nixpkgs-unstable";
        stable.follows = "nixpkgs";
      };
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs = {
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs =
    {
      self,
      nixpkgs-unstable,
      nixpkgs,
      nixos-hardware,
      colmena,
      agenix,
      ...
    }@flake-inputs:

    let
      inherit (nixpkgs-unstable) lib;
      inherit (import ./lib flake-inputs) defineHost deviceProfiles makeImage;

      domain = "selfhosted.city";
      datacenter = "nova";

      # A subset of Hydra's standard architectures.
      standardSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Necessary evils with non-free licenses.
      evilPackages = [ ];

      # Load nixpkgs with home-lab overrides.
      loadPkgs =
        { system }:
        import nixpkgs {
          inherit system;

          config = {
            allowUnfreePredicate = pkg: lib.elem (lib.getName pkg) evilPackages;
          };

          overlays = [
            self.overlays.unstable-packages
          ];
        };

      # Attrs { system -> pkgs }
      packageUniverse = lib.genAttrs standardSystems (system: loadPkgs { inherit system; });

      eachSystem = lib.flip lib.mapAttrs packageUniverse;

      # Each record maps to `config.lab.host`.
      hosts = with deviceProfiles; {
        nas-001 = {
          module = ./hosts/nas-001.nix;
          profile = cm3588;
          system = "aarch64-linux";
          ip4 = "10.0.0.15";
          interface = "enP4p65s0";
          publicKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOx6MIH8pVfBi0dckuIgssJO5JzlnEKrJrhNSPs7giTR" ];
        };
        rpi4-001 = {
          module = ./hosts/rpi4-001.nix;
          profile = raspberry-pi-4;
          system = "aarch64-linux";
          ip4 = "10.0.0.1"; # Router
          interface = null; # No "primary" interface.
          publicKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAyb4vh9xDEEV+30G0UPMTSdtVq3Tyfgl9I9VRwf226v" ];
        };
        rpi4-002 = {
          module = ./hosts/rpi4-002.nix;
          profile = raspberry-pi-4;
          system = "aarch64-linux";
          ip4 = "10.0.0.208";
          interface = "end0";
          builder.enable = true;
          publicKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJLMZ6+HaPahE4gGIAWW/uGIl/y40p/rSfIhb5t4G+g9" ];
        };
        rpi4-003 = {
          module = ./hosts/rpi4-003.nix;
          profile = raspberry-pi-4;
          system = "aarch64-linux";
          ip4 = "10.0.0.204";
          interface = "end0";
          builder.enable = true;
          publicKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFsNbo3bbm0G11GAbRwnr944AitRyqoQMN4LG7rMsvpK" ];
        };
      };

      hive = colmena.lib.makeHive self.colmena;
    in
    {
      nixosModules = {
        nixos-platform = ./platforms/nixos/modules;
        home-manager-platform = ./platforms/home-manager/modules;
      };

      overlays = {
        # Add `pkgs.unstable` to the package set.
        unstable-packages = final: prev: {
          unstable = import nixpkgs-unstable {
            inherit (prev.stdenv.hostPlatform) system;
            inherit (prev) config;
          };
        };
      };

      # Workaround for unlocked inputs in pure evaluations using newer
      # versions of Nix. Supports Colmena's `--experimental-flake-eval` flag.
      # See: https://github.com/zhaofengli/colmena/issues/202
      colmenaHive = hive;

      colmena = (lib.mapAttrs defineHost hosts) // rec {
        defaults.lab = {
          inherit datacenter domain;

          networks = {
            datacenter.ipv4 = {
              cidr = "10.0.0.1/24";
              dhcp.pools = [
                {
                  start = "10.0.0.10";
                  end = "10.0.0.200";
                }
              ];
            };

            home.ipv4 = {
              cidr = "10.0.1.1/24";
              dhcp.pools = [
                {
                  start = "10.0.1.10";
                  end = "10.0.1.250";
                }
              ];
            };

            iot.ipv4 = {
              cidr = "10.0.2.1/24";
              dhcp.pools = [
                {
                  start = "10.0.2.10";
                  end = "10.0.2.250";
                }
              ];
            };

            work.ipv4 = {
              cidr = "10.0.3.1/24";
              dhcp.pools = [
                {
                  start = "10.0.3.10";
                  end = "10.0.3.250";
                }
              ];
            };

            guest.ipv4 = {
              cidr = "10.0.4.1/24";
              dhcp.pools = [
                {
                  start = "10.0.4.10";
                  end = "10.0.4.250";
                }
              ];
            };
          };
        };

        meta = {
          description = defaults.lab.domain;

          nixpkgs = loadPkgs {
            # This value is required, but I want host to specify it instead.
            # By selecting an intentionally wrong value they are forced to
            # override it; Bad things will happen if they do not.
            system = "riscv64-linux";
          };

          # Match each host with the packages for its architecture.
          nodeNixpkgs = lib.mapAttrs (_: host: packageUniverse.${host.system}) hosts;
        };
      };

      devShells = eachSystem (
        system: pkgs:
        let
          baseShellEnvironment = pkgs.mkShell {
            packages = [
              pkgs.nixVersions.latest
              pkgs.opentofu
              colmena.packages.${system}.colmena
              agenix.packages.${system}.default

              (pkgs.unstable.writers.writeNuBin "project-bootstrap"
                # nu
                ''
                  # Build a bootable image for a specific host.
                  export def main [
                    host: string  # Host name to build image for
                    --arch: string = "aarch64-linux"  # Target architecture
                  ] {
                    nix build $".#packages.($arch).($host)-image"
                    readlink -f result
                  }
                ''
              )

              (pkgs.unstable.writers.writeNuBin "project-sandbox"
                # nu
                ''
                  # Enter a VM sandbox for experimentation.
                  export def main [] {
                    nix run ".#tests.sandbox.driver"
                  }
                ''
              )

              (pkgs.unstable.writers.writeNuBin "project-test"
                # nu
                ''
                  # Run one of the tests under `nixos/tests`.
                  export def main [
                    expr: string  # dot.separated test path under `outputs.tests`
                  ] {
                    nix run $".#tests.($expr).driver"
                  }
                ''
              )

            ];

            # NOTE: Configuring remote builds through the client assumes you
            # are a trusted Nix user. Without permission, you'll see errors
            # where it refuses to compile a foreign architecture.
            NIX_CONFIG = ''
              experimental-features = nix-command flakes
              builders-use-substitutes = true
              builders = @${pkgs.writeText "nix-remote-builders" ''
                ${lib.pipe hive.nodes [
                  (lib.mapAttrs (_: node: node.config.lab.host))
                  (lib.filterAttrs (_: host: host.builder.enable))
                  (lib.mapAttrsToList (_: host: host.builder.conf))
                  (lib.concatStringsSep "\n")
                ]}
              ''}
            '';
          };

          # Some modules require special tools or languages for development.
          # The pattern is to take the base development shell and extend it.
          devShellSpecializations = lib.mergeAttrsList (
            map (
              relativePath:

              let
                absolutePath = ./. + "/${relativePath}";
                customizeShell = import absolutePath { inherit pkgs; };
                shell = baseShellEnvironment.overrideAttrs customizeShell;
                dirname = lib.pipe relativePath [
                  (lib.splitString "/")
                  (lib.reverseList)
                  (lib.drop 1)
                  (lib.reverseList)
                  (lib.concatStringsSep "/")
                  (dir: dir + "/")
                ];
              in

              {
                ${dirname} = shell;
              }
            ) [ "platforms/nixos/modules/lab/filesystems/zfs/develop.nix" ]
          );
        in

        # Each shell is indexed by its relative project path. This avoids
        # conflicts and can be derived using `git rev-parse --show-prefix`.
        devShellSpecializations // { default = baseShellEnvironment; }
      );

      packages =
        let
          # Create a bootable disk image for each machine.
          hostImages = lib.foldlAttrs (
            packages: hostName: node:
            lib.recursiveUpdate packages {
              ${node.pkgs.stdenv.hostPlatform.system}."${hostName}-image" = makeImage {
                inherit nixpkgs;
                nixosSystem = node;
              };
            }
          ) { } hive.nodes;

          # Create a pseudo-package `tests` that holds all `nixosTest` drvs
          # underneath. This is useful to escape the flat namespace constraint
          # of `flake.packages` while remaining easily scriptable.
          testScripts = eachSystem (
            system: pkgs: {
              docs = pkgs.callPackage ./platforms/nixos/doc {
                inherit (flake-inputs) colmena home-manager;
                revision = self.rev or "latest";
              };

              # Building this package will run all tests. This is probably not
              # what you want. Instead, build individual tests by path.
              tests = pkgs.stdenvNoCC.mkDerivation rec {
                name = "tests";
                phases = [ "installPhase" ];

                buildInputs = lib.collect (value: value ? __test) passthru;
                installPhase = ''
                  touch $out
                '';

                # All tests are exposed as attributes on this derivation. You can
                # build them by path:
                # ```
                # nix build .#tests.<module>.<test-name>
                # ```
                passthru = pkgs.callPackage ./platforms/nixos/tests {
                  inherit (flake-inputs)
                    colmena
                    home-manager
                    agenix
                    ;
                };
              };
            }
          );
        in
        lib.recursiveUpdate hostImages testScripts;
    };
}
