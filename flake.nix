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

      labSettings = {
        domain = "selfhosted.city";
        datacenter = "lab1";
      };

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

      hosts = with deviceProfiles; {
        rpi3-001 = {
          module = ./hosts/rpi3-001;
          device = raspberry-pi-3;
          system = "aarch64-linux";
          ethernet = "b8:27:eb:60:f5:88";
          ip4 = "10.0.0.203";
        };
        rpi3-002 = {
          module = ./hosts/rpi3-002;
          device = raspberry-pi-3;
          system = "aarch64-linux";
          ethernet = "b8:27:eb:0b:a2:ff";
          ip4 = "10.0.0.202";
        };
        rpi4-001 = {
          module = ./hosts/rpi4-001;
          device = raspberry-pi-4;
          system = "aarch64-linux";
          ethernet = "dc:a6:32:e1:42:81";
          ip4 = "10.0.0.1"; # Router
        };
        rpi4-002 = {
          module = ./hosts/rpi4-002;
          device = raspberry-pi-4;
          system = "aarch64-linux";
          ethernet = "e4:5f:01:0e:c7:66";
          ip4 = "10.0.0.208";
        };
        rpi4-003 = {
          module = ./hosts/rpi4-003;
          device = raspberry-pi-4;
          system = "aarch64-linux";
          ethernet = "dc:a6:32:77:bb:82";
          ip4 = "10.0.0.204";
        };
      };

    in {
      overlays = {
        # Add `pkgs.unstable` to the package set.
        unstable-packages = self: pkgs: {
          unstable = import nixpkgs-unstable { inherit (pkgs) system; };
        };
      };

      colmena = (lib.mapAttrs defineHost hosts) // {
        defaults.lab.settings = labSettings;

        meta = {
          description = labSettings.domain;

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
          buildInputs = [ pkgs.nixUnstable pkgs.colmena ];

          # NOTE: Configuring remote builds through the client assumes you
          # are a trusted Nix user. Without permission, you'll see errors
          # where it refuses to compile a foreign architecture.
          NIX_CONFIG = with labSettings; ''
            experimental-features = nix-command flakes
            builders-use-substitutes = true
            builders = @${
              pkgs.writeText "nix-remote-builders" ''
                ${lib.pipe hosts (with lib; [
                  (filterAttrs
                    (_: host: host.device == deviceProfiles.raspberry-pi-4))

                  (mapAttrsToList (hostName: host:
                    "ssh://root@${hostName}.host.${domain} ${host.system} /root/.ssh/home_lab 4 1 kvm"))

                  (concatStringsSep "\n")
                ])}
              ''
            }
          '';
        });

      formatter = eachSystem (system: pkgs: pkgs.nixfmt);

      # Create a bootable SD image for each machine.
      packages = let hive = colmena.lib.makeHive self.colmena;
      in lib.foldlAttrs (packages: hostName: node:
        lib.recursiveUpdate packages {
          ${node.pkgs.system}."${hostName}-image" = makeImage {
            inherit nixpkgs;
            nixosSystem = node;
          };
        }) { } hive.nodes;
    };
}
