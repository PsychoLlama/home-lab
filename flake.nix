{
  description = "Hobbyist home lab";

  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    clapfile.url = "github:PsychoLlama/clapfile";

    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    colmena = {
      url = "github:zhaofengli/colmena/release-0.4.x";
      inputs = {
        nixpkgs.follows = "nixpkgs-unstable";
        stable.follows = "nixpkgs";
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
      clapfile,
      ...
    }@flake-inputs:

    let
      inherit (nixpkgs-unstable) lib;
      inherit (import ./lib flake-inputs) defineHost deviceProfiles makeImage;

      # A subset of Hydra's standard architectures.
      standardSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Necessary evils with non-free licenses.
      # To be replaced the instant there is a viable alternative.
      evilPackages = [ "vault-bin" ];

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
            self.overlays.testing
            clapfile.overlays.programs
          ];
        };

      # Attrs { system -> pkgs }
      packageUniverse = lib.genAttrs standardSystems (system: loadPkgs { inherit system; });

      eachSystem = lib.flip lib.mapAttrs packageUniverse;

      # Each record maps to `config.lab.host`.
      hosts = with deviceProfiles; {
        rpi3-001 = {
          module = ./hosts/rpi3-001.nix;
          profile = raspberry-pi-3;
          system = "aarch64-linux";
          ethernet = "b8:27:eb:60:f5:88";
          ip4 = "10.0.0.203";
        };
        rpi3-002 = {
          module = ./hosts/rpi3-002.nix;
          profile = raspberry-pi-3;
          system = "aarch64-linux";
          ethernet = "b8:27:eb:0b:a2:ff";
          ip4 = "10.0.0.202";
        };
        rpi4-001 = {
          module = ./hosts/rpi4-001.nix;
          profile = raspberry-pi-4;
          system = "aarch64-linux";
          ethernet = "dc:a6:32:e1:42:81";
          ip4 = "10.0.0.1"; # Router
        };
        rpi4-002 = {
          module = ./hosts/rpi4-002.nix;
          profile = raspberry-pi-4;
          system = "aarch64-linux";
          ethernet = "e4:5f:01:0e:c7:66";
          ip4 = "10.0.0.208";
          builder.enable = true;
        };
        rpi4-003 = {
          module = ./hosts/rpi4-003.nix;
          profile = raspberry-pi-4;
          system = "aarch64-linux";
          ethernet = "dc:a6:32:77:bb:82";
          ip4 = "10.0.0.204";
          builder.enable = true;
        };
      };

      hive = colmena.lib.makeHive self.colmena;
    in
    {
      overlays = {
        # Add `pkgs.unstable` to the package set.
        unstable-packages = final: prev: {
          unstable = import nixpkgs-unstable { inherit (prev) system config; };
        };

        # `runTest` is a souped up version of `nixosTest`.
        testing = final: prev: { inherit (import (final.path + "/nixos/lib") { }) runTest; };
      };

      colmena = (lib.mapAttrs defineHost hosts) // rec {
        defaults.lab = {
          domain = "selfhosted.city";
          datacenter = "nova";

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
              pkgs.nixUnstable
              pkgs.colmena

              (pkgs.clapfile.command {
                command = {
                  name = "project";
                  about = "Project task runner";
                  subcommands = {
                    bootstrap = {
                      about = "Build a bootable image for a specific host.";
                      run = pkgs.writers.writeBash "bootstrap" ''
                        set -eux
                        nix build ".#packages.$arch.$host-image"
                        readlink -f result
                      '';

                      args = [
                        {
                          id = "host";
                          required = true;
                        }
                        {
                          id = "arch";
                          long = "arch";
                          value_name = "system";
                          default_value = "aarch64-linux";
                        }
                      ];
                    };

                    sandbox = {
                      about = "Enter a VM sandbox for experimentation.";
                      run = pkgs.writers.writeBash "sandbox" ''
                        set -eux
                        nix run ".#tests.sandbox.driver"
                      '';
                    };

                    test = {
                      about = "Run one of the tests under `nixos/tests`.";
                      run = pkgs.writers.writeBash "test" ''
                        set -eux

                        # This is the only way to use `.shell_interact()`.
                        if [[ -n "$interactive" ]]; then
                          nix run ".#tests.$expr.driver"
                        else
                          nix build ".#tests.$expr"
                        fi
                      '';

                      args = [
                        {
                          id = "expr";
                          value_name = "test-path";
                          help = "dot.separated test path under `outputs.tests`";
                          required = true;
                        }
                        {
                          id = "interactive";
                          long = "interactive";
                          short = "i";
                          default_value = "";
                          help = "Enable interaction via stdout/stdin.";
                        }
                      ];
                    };
                  };
                };
              })
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
            ) [ "nixos/modules/lab/filesystems/zfs/develop.nix" ]
          );
        in

        # Each shell is indexed by its relative project path. This avoids
        # conflicts and can be derived using `git rev-parse --show-prefix`.
        devShellSpecializations // { default = baseShellEnvironment; }
      );

      formatter = eachSystem (system: pkgs: pkgs.nixfmt);

      packages =
        let
          # Create a bootable disk image for each machine.
          hostImages = lib.foldlAttrs (
            packages: hostName: node:
            lib.recursiveUpdate packages {
              ${node.pkgs.system}."${hostName}-image" = makeImage {
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
              docs = pkgs.callPackage ./nixos/doc {
                inherit (flake-inputs) colmena home-manager clapfile;
                revision = self.rev or "latest";
              };

              tests = pkgs.stdenvNoCC.mkDerivation {
                name = "tests";
                phases = [ "installPhase" ];
                installPhase =
                  lib.warn
                    ''
                      This is not meant to be built. It only exists to hold other tests.
                    ''
                    ''
                      touch $out
                    '';

                # All tests are exposed as attributes on this derivation. You can
                # build them by path:
                # ```
                # nix build .#tests.<module>.<test-name>
                # ```
                passthru = pkgs.callPackage ./nixos/tests { inherit (flake-inputs) colmena clapfile home-manager; };
              };
            }
          );
        in
        lib.recursiveUpdate hostImages testScripts;
    };
}
