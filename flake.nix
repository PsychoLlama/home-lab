{
  description = "Hobbyist home lab";
  inputs.nixpkgs.url = "nixpkgs";

  outputs = { self, nixpkgs }:
    let lib = import ./machines/lib.nix;

    in {
      nixopsConfigurations = {
        default = {
          inherit nixpkgs;

          network = {
            description = lib.domain;
            enableRollback = true;
            storage.legacy = { databasefile = "~/.nixops/deployments.nixops"; };
          };

          multivac = lib.defineHost ./machines/hosts/multivac;
          viki = lib.defineHost ./machines/hosts/viki;
          hal = lib.defineHost ./machines/hosts/hal;
          clu = lib.defineHost ./machines/hosts/clu;
          tron = lib.defineHost ./machines/hosts/tron;
        };
      };
    };
}
