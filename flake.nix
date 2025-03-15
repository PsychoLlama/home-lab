{
  description = "Hobbyist home lab";

  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    clapfile.url = "github:PsychoLlama/clapfile";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
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
      clapfile,
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
          ip4 = "10.0.0.203";
          interface = "enu1u1";
          publicKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN2VZGgphnMAD5tLG+IHBlBWdlUPNfvYEMDK8OQCrG/A" ];
        };
        rpi3-002 = {
          module = ./hosts/rpi3-002.nix;
          profile = raspberry-pi-3;
          system = "aarch64-linux";
          ip4 = "10.0.0.202";
          interface = "enu1u1";
          publicKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKrGfslz9RlB2EzrTL3SfO/NZB5fPiVXWkK+aQRZrlel" ];
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
          unstable = import nixpkgs-unstable { inherit (prev) system config; };
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
              colmena.packages.${system}.colmena
              agenix.packages.${system}.default

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
                        nix run ".#tests.$expr.driver"
                      '';

                      args = [
                        {
                          id = "expr";
                          value_name = "test-path";
                          help = "dot.separated test path under `outputs.tests`";
                          required = true;
                        }
                      ];
                    };

                    vpn = {
                      about = "Manage the VPN.";
                      subcommands.register = {
                        about = "Register a node on the VPN.";
                        args = [
                          {
                            id = "host";
                            about = "Host to initialize.";
                            required = true;
                          }
                          {
                            id = "server_url";
                            about = "URL of the VPN server.";
                            short = "s";
                            long = "server-url";
                            default_value = "http://rpi4-003.host.${datacenter}.${domain}:8080";
                          }
                        ];

                        # TODO: Use Colmena's deploy key commands instead and
                        # defer the oneshot setup by the key service.
                        run = pkgs.unstable.writers.writeNu "bootstrap-vpn-client.nu" ''
                          use std/log

                          let server_host = $env.server_url | url parse | get host
                          let response = ssh $server_host headscale preauthkey create --user dc-${datacenter} --output json | from json
                          log info $"Auth key created id=($response.id)"

                          ssh $env.host tailscale up --login-server $env.server_url --auth-key $response.key
                          log info "VPN client ready"
                        '';
                      };
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
              docs = pkgs.callPackage ./platforms/nixos/doc {
                inherit (flake-inputs) colmena home-manager clapfile;
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
                  inherit (flake-inputs) colmena clapfile home-manager;
                };
              };
            }
          );
        in
        lib.recursiveUpdate hostImages testScripts;
    };
}
