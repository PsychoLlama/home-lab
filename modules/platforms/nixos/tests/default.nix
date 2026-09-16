{
  pkgs,
  inputs,
  flake,
}:

let
  inherit (pkgs) lib;

  baseModule = {
    # Match the `flake` argument colmena gives every node.
    node.specialArgs = { inherit flake; };

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
        extraSpecialArgs = { inherit flake; };
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
