{ withSystem, ... }:

let
  # TODO: Fix this abominable hack. Ideally port IP parsing to pure Nix.
  #
  # CIDR parsing uses import-from-derivation, so the helper must be buildable
  # by the machine *evaluating* the config, not the target. Otherwise
  # evaluating an aarch64 host from x86_64 fails trying to build an aarch64
  # derivation. `currentSystem` is unavailable in pure evaluation (colmena,
  # flakes), so assume the deploy workstation there.
  evalPkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  buildCidrInfo = evalPkgs.writers.writePython3 "print_cidr_info" { } ''
    from ipaddress import ip_interface
    import sys
    import json

    # Expects a CIDR address as the first argument.
    interface = ip_interface(sys.argv[1])
    data = json.dumps({
        "gatewayAddress": str(interface.ip),
        "networkAddress": str(interface.network.network_address),
        "broadcastAddress": str(interface.network.broadcast_address),
        "prefixLength": interface.network.prefixlen,
        "subnetMask": str(interface.network.netmask),
        "subnet": str(interface.network),
    })

    print(data)
  '';
in

{
  # Run the python script passing the CIDR address. Read the file back as
  # JSON, providing the data as a Nix value.
  flake.lib.cidr.v4.parse =
    cidr_address:
    builtins.fromJSON (
      builtins.readFile (
        evalPkgs.runCommandLocal "cidr-info" { inherit cidr_address; } ''
          ${buildCidrInfo} $cidr_address > $out
        ''
      )
    );
}
