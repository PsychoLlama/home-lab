{
  description = "Hobbyist home lab";

  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/22.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = { self, nixpkgs-unstable, nixpkgs, nixos-hardware, ... }:
    let
      inherit (nixpkgs) lib;
      inherit (import ./lib) defineHost;

      # A subset of Hydra's standard architectures.
      standardSystems = [ "x86_64-linux" "aarch64-linux" ];

      loadPkgs = { system }:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlays.unstable-packages ];
        };

      eachSystem = f:
        lib.pipe standardSystems [
          (map (system: loadPkgs { inherit system; }))
          (map (pkgs: lib.nameValuePair pkgs.system pkgs))
          lib.listToAttrs
          (lib.mapAttrs f)
        ];

      hosts = (lib.mapAttrs defineHost {
        clu = ./hosts/clu;
        glados = ./hosts/glados;
        tron = ./hosts/tron;
        hal = ./hosts/hal;
        viki = ./hosts/viki;
      });

    in {
      overlays = {
        # Add `pkgs.unstable` to the package set.
        unstable-packages = self: pkgs: {
          unstable = import nixpkgs-unstable { inherit (pkgs) system; };
        };
      };

      colmena = hosts // rec {
        meta = {
          description = defaults.lab.settings.domain;

          nixpkgs = loadPkgs {
            # This value is required, but I want host to specify it instead.
            # By selecting an intentionally wrong value they are forced to
            # override it; Bad things will happen if they do not.
            system = "riscv64-linux";
          };

          specialArgs = { inherit nixos-hardware; };

          # TODO: Test `machinesFile` as an alternative way to configure
          # remote builders.
        };

        defaults.lab.settings = {
          domain = "selfhosted.city";
          datacenter = "lab1";
        };
      };

      devShell = eachSystem (system: pkgs:
        pkgs.mkShell {
          buildInputs = with pkgs; [ nixUnstable colmena ];

          # NOTE: Configuring remote builds through the client assumes you
          # are a trusted Nix user. Without permission, you'll see errors
          # where it refuses to compile a foreign architecture.
          NIX_CONFIG = ''
            experimental-features = nix-command flakes
            builders-use-substitutes = true
            builders = @${
              pkgs.writeText "nix-remote-builders" ''
                ssh://root@glados.host.selfhosted.city aarch64-linux /root/.ssh/home_lab 4
                ssh://root@tron.host.selfhosted.city aarch64-linux /root/.ssh/home_lab 4
                ssh://root@clu.host.selfhosted.city aarch64-linux /root/.ssh/home_lab 4
              ''
            }
          '';
        });

      formatter = eachSystem (system: pkgs: pkgs.nixfmt);
    };
}
