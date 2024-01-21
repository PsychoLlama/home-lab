{ pkgs, callPackage, colmena, runTest }:

let
  baseModule = {
    hostPkgs = pkgs;
    defaults.imports = [
      colmena.nixosModules.deploymentOptions
      colmena.nixosModules.assertionModule
      ../modules
    ];
  };

  makeTest = testModule: runTest { imports = [ baseModule testModule ]; };

  importTests = path: args:
    callPackage path (args // { inherit importTests makeTest; });

in {
  dhcp = importTests ./dhcp.nix { };
  file-storage = importTests ./file-storage.nix { };
}
