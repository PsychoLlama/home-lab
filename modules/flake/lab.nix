{ lib, ... }:

# Constants shared by every machine in the lab. Declared at the flake level so
# `defaults` and the colmena metadata can both read them without evaluating a
# node first.

let
  inherit (lib) mkOption types;
in

{
  options.lab = {
    domain = mkOption {
      type = types.str;
      default = "selfhosted.city";
      description = "Public domain owned by the lab.";
    };

    datacenter = mkOption {
      type = types.str;
      default = "nova";
      description = "Name of the datacenter hosting the lab.";
    };

    tailnet = mkOption {
      type = types.str;
      default = "taila3423a.ts.net";
      description = "MagicDNS domain of the lab's tailnet.";
    };
  };
}
