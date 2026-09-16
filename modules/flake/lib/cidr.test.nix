{ flake, ... }:

/**
  A snapshot of `cidr.v4.parse`'s current behavior, taken before porting it
  from import-from-derivation to pure Nix. Everything here is what Python's
  `ipaddress.ip_interface` does today, quirks included - these cases say what
  the port must keep, not what the interface ought to be.
*/
let
  inherit (flake.lib.cidr.v4) parse;
in

{
  /**
    The shape every other case is an edge of, and the one `lab.networks`
    actually uses: an address that is the gateway, and a /24 around it.
  */
  testParsesGatewayNetwork = {
    expr = parse "10.0.1.1/24";

    expected = {
      gatewayAddress = "10.0.1.1";
      networkAddress = "10.0.1.0";
      broadcastAddress = "10.0.1.255";
      prefixLength = 24;
      subnetMask = "255.255.255.0";
      subnet = "10.0.1.0/24";
    };
  };

  /**
    The address keeps its host bits - it is the interface, not the network.
    Only `gatewayAddress` carries them; the rest describe the subnet.
  */
  testKeepsHostBits = {
    expr = parse "10.0.0.37/24";

    expected = {
      gatewayAddress = "10.0.0.37";
      networkAddress = "10.0.0.0";
      broadcastAddress = "10.0.0.255";
      prefixLength = 24;
      subnetMask = "255.255.255.0";
      subnet = "10.0.0.0/24";
    };
  };

  # A mask that doesn't land on an octet boundary.
  testParsesUnalignedPrefix = {
    expr = parse "172.16.5.4/12";

    expected = {
      gatewayAddress = "172.16.5.4";
      networkAddress = "172.16.0.0";
      broadcastAddress = "172.31.255.255";
      prefixLength = 12;
      subnetMask = "255.240.0.0";
      subnet = "172.16.0.0/12";
    };
  };

  # A /32 is its own network and its own broadcast address.
  testParsesSingleHost = {
    expr = parse "10.0.0.1/32";

    expected = {
      gatewayAddress = "10.0.0.1";
      networkAddress = "10.0.0.1";
      broadcastAddress = "10.0.0.1";
      prefixLength = 32;
      subnetMask = "255.255.255.255";
      subnet = "10.0.0.1/32";
    };
  };

  /**
    A /31 point-to-point link has no room for a broadcast address, and the
    upper of its two addresses is reported as one anyway.
  */
  testParsesPointToPointLink = {
    expr = parse "10.0.0.1/31";

    expected = {
      gatewayAddress = "10.0.0.1";
      networkAddress = "10.0.0.0";
      broadcastAddress = "10.0.0.1";
      prefixLength = 31;
      subnetMask = "255.255.255.254";
      subnet = "10.0.0.0/31";
    };
  };

  # A /0 spans the entire address space.
  testParsesDefaultRoute = {
    expr = parse "0.0.0.0/0";

    expected = {
      gatewayAddress = "0.0.0.0";
      networkAddress = "0.0.0.0";
      broadcastAddress = "255.255.255.255";
      prefixLength = 0;
      subnetMask = "0.0.0.0";
      subnet = "0.0.0.0/0";
    };
  };

  /**
    Anything unparseable fails the build, and the builder's log rides along
    in the error, which is why the input can be matched at all. A pure-Nix
    port will word this differently; what must survive is that the input is
    rejected rather than guessed at.
  */
  testRejectsMalformedAddress = {
    expr = parse "192.168.1.1/33";

    expectedError = {
      type = "Error";
      msg = "192.168.1.1/33";
    };
  };
}
