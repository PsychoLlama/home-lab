{ pkgs, callPackage, colmena }:

let
  baseModule = {
    hostPkgs = pkgs;
    defaults.imports = [
      colmena.nixosModules.deploymentOptions
      colmena.nixosModules.assertionModule
      ../modules
    ];
  };

  loadTest = path: args:
    callPackage path (args // { inherit loadTest baseModule; });

in {
  dhcp = loadTest ./dhcp.nix { };
  # ...
}
