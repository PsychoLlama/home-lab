{ flake, ... }:

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
      subnet = {
        cidr = "10.0.1.0/24";
        mask = "255.255.255.0";
        prefixLength = 24;
      };

      addresses = {
        host = "10.0.1.1";
        network = "10.0.1.0";
        broadcast = "10.0.1.255";
      };
    };
  };

  /**
    The address keeps its host bits - it is the interface, not the network.
    Only `addresses.host` carries them; the rest describe the subnet.
  */
  testKeepsHostBits = {
    expr = parse "10.0.0.37/24";

    expected = {
      subnet = {
        cidr = "10.0.0.0/24";
        mask = "255.255.255.0";
        prefixLength = 24;
      };

      addresses = {
        host = "10.0.0.37";
        network = "10.0.0.0";
        broadcast = "10.0.0.255";
      };
    };
  };

  # A mask that doesn't land on an octet boundary.
  testParsesUnalignedPrefix = {
    expr = parse "172.16.5.4/12";

    expected = {
      subnet = {
        cidr = "172.16.0.0/12";
        mask = "255.240.0.0";
        prefixLength = 12;
      };

      addresses = {
        host = "172.16.5.4";
        network = "172.16.0.0";
        broadcast = "172.31.255.255";
      };
    };
  };

  # A /32 is its own network and its own broadcast address.
  testParsesSingleHost = {
    expr = parse "10.0.0.1/32";

    expected = {
      subnet = {
        cidr = "10.0.0.1/32";
        mask = "255.255.255.255";
        prefixLength = 32;
      };

      addresses = {
        host = "10.0.0.1";
        network = "10.0.0.1";
        broadcast = "10.0.0.1";
      };
    };
  };

  /**
    A /31 point-to-point link has no room for a broadcast address, and the
    upper of its two addresses is reported as one anyway.
  */
  testParsesPointToPointLink = {
    expr = parse "10.0.0.1/31";

    expected = {
      subnet = {
        cidr = "10.0.0.0/31";
        mask = "255.255.255.254";
        prefixLength = 31;
      };

      addresses = {
        host = "10.0.0.1";
        network = "10.0.0.0";
        broadcast = "10.0.0.1";
      };
    };
  };

  # A /0 spans the entire address space.
  testParsesDefaultRoute = {
    expr = parse "0.0.0.0/0";

    expected = {
      subnet = {
        cidr = "0.0.0.0/0";
        mask = "0.0.0.0";
        prefixLength = 0;
      };

      addresses = {
        host = "0.0.0.0";
        network = "0.0.0.0";
        broadcast = "255.255.255.255";
      };
    };
  };

  # Anything unparseable is rejected rather than guessed at.
  testRejectsMalformedAddress = {
    expr = parse "192.168.1.1/33";

    expectedError = {
      type = "ThrownError";
      msg = "prefix length 33 is out of range";
    };
  };

  # Reading one field still validates the whole input.
  testRejectsMalformedPrefixWhenReadingAddress = {
    expr = (parse "192.168.1.1/33").addresses.host;

    expectedError = {
      type = "ThrownError";
      msg = "prefix length 33 is out of range";
    };
  };
}
