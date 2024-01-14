{
  description = "Hobbyist home lab";

  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/23.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    colmena = {
      url = "github:zhaofengli/colmena/release-0.4.x";
      inputs = {
        nixpkgs.follows = "nixpkgs-unstable";
        stable.follows = "nixpkgs";
      };
    };
  };

  outputs =
    { self, nixpkgs-unstable, nixpkgs, nixos-hardware, colmena }@flake-inputs:
    let
      inherit (nixpkgs) lib;
      inherit (import ./lib flake-inputs) defineHost deviceProfiles makeImage;

      # A subset of Hydra's standard architectures.
      standardSystems = [ "x86_64-linux" "aarch64-linux" ];

      # Load nixpkgs with home-lab overrides.
      loadPkgs = { system }:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlays.unstable-packages ];
        };

      # Attrs { system -> pkgs }
      packageUniverse =
        lib.genAttrs standardSystems (system: loadPkgs { inherit system; });

      eachSystem = lib.flip lib.mapAttrs packageUniverse;

      # Each record maps to `config.lab.host`.
      hosts = with deviceProfiles; {
        rpi3-001 = {
          module = ./hosts/rpi3-001;
          profile = raspberry-pi-3;
          system = "aarch64-linux";
          ethernet = "b8:27:eb:60:f5:88";
          ip4 = "10.0.0.203";
        };
        rpi3-002 = {
          module = ./hosts/rpi3-002;
          profile = raspberry-pi-3;
          system = "aarch64-linux";
          ethernet = "b8:27:eb:0b:a2:ff";
          ip4 = "10.0.0.202";
        };
        rpi4-001 = {
          module = ./hosts/rpi4-001;
          profile = raspberry-pi-4;
          system = "aarch64-linux";
          ethernet = "dc:a6:32:e1:42:81";
          ip4 = "10.0.0.1"; # Router
        };
        rpi4-002 = {
          module = ./hosts/rpi4-002;
          profile = raspberry-pi-4;
          system = "aarch64-linux";
          ethernet = "e4:5f:01:0e:c7:66";
          ip4 = "10.0.0.208";
          builder.enable = true;
        };
        rpi4-003 = {
          module = ./hosts/rpi4-003;
          profile = raspberry-pi-4;
          system = "aarch64-linux";
          ethernet = "dc:a6:32:77:bb:82";
          ip4 = "10.0.0.204";
          builder.enable = true;
        };
      };

      hive = colmena.lib.makeHive self.colmena;

    in {
      overlays = {
        # Add `pkgs.unstable` to the package set.
        unstable-packages = self: pkgs: {
          unstable = import nixpkgs-unstable { inherit (pkgs) system; };
        };
      };

      colmena = (lib.mapAttrs defineHost hosts) // rec {
        defaults.lab = {
          domain = "selfhosted.city";
          datacenter = "lab1";

          networks = {
            datacenter.ipv4.cidr = "10.0.0.1/24";
            home.ipv4.cidr = "10.0.1.1/24";
            iot.ipv4.cidr = "10.0.2.1/24";
            work.ipv4.cidr = "10.0.3.1/24";
            guest.ipv4.cidr = "10.0.4.1/24";
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
          nodeNixpkgs =
            lib.mapAttrs (_: host: packageUniverse.${host.system}) hosts;
        };
      };

      devShell = eachSystem (system: pkgs:
        pkgs.mkShell {
          packages = [ pkgs.nixUnstable pkgs.colmena pkgs.just ];

          # NOTE: Configuring remote builds through the client assumes you
          # are a trusted Nix user. Without permission, you'll see errors
          # where it refuses to compile a foreign architecture.
          NIX_CONFIG = ''
            experimental-features = nix-command flakes
            builders-use-substitutes = true
            builders = @${
              pkgs.writeText "nix-remote-builders" ''
                ${lib.pipe hive.nodes [
                  (lib.mapAttrs (_: node: node.config.lab.host))
                  (lib.filterAttrs (_: host: host.builder.enable))
                  (lib.mapAttrsToList (_: host: host.builder.conf))
                  (lib.concatStringsSep "\n")
                ]}
              ''
            }
          '';
        });

      formatter = eachSystem (system: pkgs: pkgs.nixfmt);

      # Create a bootable SD image for each machine.
      packages = lib.foldlAttrs (packages: hostName: node:
        lib.recursiveUpdate packages {
          ${node.pkgs.system}."${hostName}-image" = makeImage {
            inherit nixpkgs;
            nixosSystem = node;
          };
        }) { } hive.nodes;
    };
}
