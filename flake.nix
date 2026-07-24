{
  description = "Hobbyist home lab";

  inputs = {
    systems.url = "github:nix-systems/default";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    colmena = {
      url = "github:zhaofengli/colmena";
      inputs = {
        nixpkgs.follows = "nixpkgs-unstable";
        stable.follows = "nixpkgs";
        flake-utils.inputs.systems.follows = "systems";
      };
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs = {
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };

  };

  outputs =
    {
      self,
      nixpkgs-unstable,
      nixpkgs,
      colmena,
      agenix,
      systems,
      ...
    }@flake-inputs:

    let
      inherit (nixpkgs-unstable) lib;
      inherit (import ./lib flake-inputs) defineHost deviceProfiles;

      domain = "selfhosted.city";
      datacenter = "nova";
      tailnet = "taila3423a.ts.net";

      # Load nixpkgs with home-lab overrides.
      loadPkgs =
        { system }:
        import nixpkgs {
          inherit system;

          overlays = [
            self.overlays.unstable-packages
          ];
        };

      # Attrs { system -> pkgs }
      pkgsBySystem = lib.genAttrs (import systems) (system: loadPkgs { inherit system; });

      eachSystem = lib.flip lib.mapAttrs pkgsBySystem;

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
          inherit datacenter domain tailnet;

          # Enable node exporter on all lab nodes for monitoring
          services.node-exporter.enable = true;

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
          nodeNixpkgs = lib.mapAttrs (_: host: pkgsBySystem.${host.system}) hosts;
        };
      };

      devShells = eachSystem (
        system: pkgs: {
          default = pkgs.mkShell {
            packages = [
              agenix.packages.${system}.default
              colmena.packages.${system}.colmena
              pkgs.unstable.just
              pkgs.unstable.mcp-grafana
              pkgs.unstable.nixVersions.latest
              pkgs.unstable.nixfmt
              pkgs.unstable.opentofu
              pkgs.unstable.treefmt
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
        }
      );

      # Export node data as JSON for Terraform consumption
      packages = eachSystem (
        _: pkgs: {
          terraform-config = pkgs.callPackage ./pkgs/terraform-config { nodes = hive.nodes; };
        }
      );

      checks = eachSystem (
        _: pkgs:

        let
          importTest = import ./platforms/nixos/tests {
            inherit pkgs;

            inputs = flake-inputs;
          };
        in

        {
          dhcp = importTest ./platforms/nixos/tests/dhcp.nix;
          dns = importTest ./platforms/nixos/tests/dns.nix;
          gateway = importTest ./platforms/nixos/tests/gateway.nix;
        }
      );
    };
}
