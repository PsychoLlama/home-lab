{
  pkgs,
  callPackage,
  colmena,
  clapfile,
  home-manager,
}:

let
  baseModule = {
    defaults = {
      imports = [
        colmena.nixosModules.deploymentOptions
        colmena.nixosModules.assertionModule
        home-manager.nixosModules.home-manager
        clapfile.nixosModules.nixos
        ../modules
      ];

      home-manager = {
        sharedModules = [ ../../home-manager/modules ];
        useGlobalPkgs = true;
        useUserPackages = true;
      };
    };
  };

  makeTest =
    testModule:
    (pkgs.testers.runNixOSTest {
      imports = [
        baseModule
        testModule
      ];
    })
    // {
      __test = true;
    };

  importTests = path: args: callPackage path (args // { inherit importTests makeTest; });
in
{
  dhcp = importTests ./dhcp.nix { };
  dns = importTests ./dns.nix { };
  filesystems = importTests ./filesystems { };
  gateway = importTests ./gateway.nix { };

  # A place to experiment locally. This is much faster than waiting for
  # a Colmena deploy.
  sandbox = importTests ./sandbox.nix { };
}
