{ pkgs, inputs }:

let
  inherit (pkgs) lib;

  baseModule = {
    defaults = {
      imports = [
        inputs.colmena.nixosModules.deploymentOptions
        inputs.colmena.nixosModules.assertionModule
        inputs.home-manager.nixosModules.home-manager
        inputs.agenix.nixosModules.default
        inputs.self.nixosModules.nixos-platform
      ];

      home-manager = {
        sharedModules = [ inputs.self.homeModules.home-manager-platform ];
        useGlobalPkgs = true;
        useUserPackages = true;
      };
    };
  };

  defineLabTest =
    testModule:
    pkgs.testers.runNixOSTest {
      imports = [
        baseModule
        testModule
      ];
    };
in

# Import a single VM test module, injecting the shared test helpers.
path: import path { inherit defineLabTest lib; }
