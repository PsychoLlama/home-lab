# This uses Nixops to manage all machines on the network.
let
  lib = import ./lib.nix;

in {
  network = {
    description = lib.domain;
    enableRollback = true;
  };

  corvus = lib.defineHost ./hosts/corvus;
  clu = lib.defineHost ./hosts/clu;
}
