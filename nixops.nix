# This uses Nixops to manage all machines on the network.
let lib = import ./machines/lib.nix;

in {
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
}
