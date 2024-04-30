{ pkgs, callPackage, colmena, clapfile, runTest }:

let
  baseModule = {
    hostPkgs = pkgs;
    defaults.imports = [
      colmena.nixosModules.deploymentOptions
      colmena.nixosModules.assertionModule
      clapfile.nixosModules.nixos
      ../modules

      # The VM package set does not include overlays from the host.
      { nixpkgs.overlays = pkgs.overlays; }
    ];
  };

  makeTest = testModule: runTest { imports = [ baseModule testModule ]; };

  importTests = path: args:
    callPackage path (args // { inherit importTests makeTest; });

in {
  dhcp = importTests ./dhcp.nix { };
  filesystems = importTests ./filesystems { };
}
