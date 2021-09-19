# This uses Nixops to manage all machines on the network.
let lib = import ./lib.nix;

in {
  network = {
    description = lib.domain;
    enableRollback = true;
  };

  cluster-manager = lib.defineHost ./hosts/cluster-manager;
  corvus = lib.defineHost ./hosts/corvus;
  clu = lib.defineHost ./hosts/clu;
  tron = lib.defineHost ./hosts/tron;
}
