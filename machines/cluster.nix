# This uses Nixops to manage all machines on the network.
let lib = import ./lib.nix;

in {
  network = {
    description = lib.domain;
    enableRollback = true;
  };

  viki = lib.defineHost ./hosts/viki;
  clu = lib.defineHost ./hosts/clu;
  tron = lib.defineHost ./hosts/tron;
}
