# This uses Nixops to manage all machines on the network.
let lib = import ./lib.nix;

in {
  network = {
    description = lib.domain;
    enableRollback = true;
  };

  multivac = lib.defineHost ./hosts/multivac;
  viki = lib.defineHost ./hosts/viki;
  hal = lib.defineHost ./hosts/hal;
  clu = lib.defineHost ./hosts/clu;
  tron = lib.defineHost ./hosts/tron;
}
