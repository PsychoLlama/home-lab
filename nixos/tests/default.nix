{
  pkgs,
  callPackage,
  colmena,
  clapfile,
  home-manager,
  runTest,
}:

let
  baseModule = {
    hostPkgs = pkgs;

    defaults = {
      imports = [
        colmena.nixosModules.deploymentOptions
        colmena.nixosModules.assertionModule
        home-manager.nixosModules.home-manager
        clapfile.nixosModules.nixos
        ../modules
      ];

      # The VM package set does not include overlays from the host.
      nixpkgs.overlays = pkgs.overlays;

      home-manager = {
        sharedModules = [ ../../home-manager/modules ];
        useGlobalPkgs = true;
        useUserPackages = true;
      };
    };
  };

  makeTest =
    testModule:
    runTest {
      imports = [
        baseModule
        testModule
      ];
    };

  importTests = path: args: callPackage path (args // { inherit importTests makeTest; });
in
{
  dhcp = importTests ./dhcp.nix { };
  dns = importTests ./dns.nix { };
  filesystems = importTests ./filesystems { };

  # A place to experiment locally. This is much faster than waiting for
  # a Colmena deploy.
  sandbox = makeTest {
    name = "sandbox-environment";

    nodes.machine =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.hello ];
      };

    testScript = ''
      start_all()
      machine.shell_interact()
    '';
  };
}
