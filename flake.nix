{
  description = "Hobbyist home lab";

  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/23.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = { self, nixpkgs-unstable, nixpkgs, nixos-hardware }@flake-inputs:
    let
      inherit (nixpkgs) lib;
      inherit (import ./lib flake-inputs) defineHost deviceProfiles;

      constants = {
        domain = "selfhosted.city";
        datacenter = "lab1";
      };

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

      hosts = with deviceProfiles; {
        rpi3-001 = {
          module = ./hosts/rpi3-001;
          device = raspberry-pi-3;
        };
        rpi3-002 = {
          module = ./hosts/rpi3-002;
          device = raspberry-pi-3;
        };
        rpi4-001 = {
          module = ./hosts/rpi4-001;
          device = raspberry-pi-4;
        };
        rpi4-002 = {
          module = ./hosts/rpi4-002;
          device = raspberry-pi-4;
        };
        rpi4-003 = {
          module = ./hosts/rpi4-003;
          device = raspberry-pi-4;
        };
      };

      hive = lib.mapAttrs defineHost hosts;

    in {
      overlays = {
        # Add `pkgs.unstable` to the package set.
        unstable-packages = self: pkgs: {
          unstable = import nixpkgs-unstable { inherit (pkgs) system; };
        };
      };

      colmena = hive // {
        meta = {
          description = constants.domain;

          nixpkgs = loadPkgs {
            # This value is required, but I want host to specify it instead.
            # By selecting an intentionally wrong value they are forced to
            # override it; Bad things will happen if they do not.
            system = "riscv64-linux";
          };

          # TODO: Test `machinesFile` as an alternative way to configure
          # remote builders.
        };

        defaults.lab.settings = constants;
      };

      devShell = eachSystem (system: pkgs:
        pkgs.mkShell {
          buildInputs = with pkgs; [ nixUnstable colmena ];

          # NOTE: Configuring remote builds through the client assumes you
          # are a trusted Nix user. Without permission, you'll see errors
          # where it refuses to compile a foreign architecture.
          NIX_CONFIG = with constants; ''
            experimental-features = nix-command flakes
            builders-use-substitutes = true
            builders = @${
              pkgs.writeText "nix-remote-builders" ''
                ssh://root@rpi4-001.host.${domain} aarch64-linux /root/.ssh/home_lab 4
                ssh://root@rpi4-002.host.${domain} aarch64-linux /root/.ssh/home_lab 4
                ssh://root@rpi4-003.host.${domain} aarch64-linux /root/.ssh/home_lab 4
              ''
            }
          '';
        });

      formatter = eachSystem (system: pkgs: pkgs.nixfmt);
    };
}
