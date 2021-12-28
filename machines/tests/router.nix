{ pkgs ? import ../unstable-pkgs.nix { } }:

let
  routerBase = {
    imports = [ ../services/router.nix ];
    virtualisation.vlans = [ 1 2 ];
    networking.interfaces.eth1.useDHCP = false;

    lab.router = {
      enable = true;
      debugging.enable = true;
      network.wan.interface = "eth1";
      network.lan.interface = "eth2";
    };
  };

  clientBase = {
    virtualisation.vlans = [ 2 ];
    networking = {
      useDHCP = false;
      interfaces.eth1.useDHCP = true;
    };
  };

in {
  basic = pkgs.nixosTest {
    name = "router-basic";
    nodes = {
      router = routerBase;
      alice = clientBase;
      bob = clientBase;
    };

    testScript = ''
      start_all()

      with subtest("Wait for network to come online"):
        alice.wait_for_unit("network-online.target")
        bob.wait_for_unit("network-online.target")

      with subtest("Test DHCP assignment"):
        alice.succeed("ip addr show eth1 to 10.0.0.1/24 | grep inet")
        bob.succeed("ip addr show eth1 to 10.0.0.1/24 | grep inet")

      # This is partially implied by successful DHCP. It's more or less to see
      # if ICMP is blocked at the firewall and whether the gateway is
      # accepting traffic.
      with subtest("Test basic connectivity to router"):
        alice.succeed("ping -c 1 10.0.0.1")

      # Most of the work is done by the vlan. It just ensures both clients got
      # a routable, non-conflicting IP.
      with subtest("Test communication between clients"):
        alice.wait_until_succeeds("ping -c 1 10.0.0.10")
        alice.wait_until_succeeds("ping -c 1 10.0.0.11")

        bob.wait_until_succeeds("ping -c 1 10.0.0.10")
        bob.wait_until_succeeds("ping -c 1 10.0.0.11")
    '';
  };

  nat = pkgs.nixosTest {
    name = "router-nat";
    nodes = {
      router = routerBase;
      client = clientBase;
      server = {
        virtualisation.vlans = [ 1 ];
        services.httpd.enable = true;
        services.httpd.adminAddr = "foo@example.com";
        networking.firewall.allowedTCPPorts = [ 80 ];
      };
    };

    testScript = ''
      start_all()

      server.wait_for_unit("network-online.target")
      server.wait_for_unit("httpd")

      with subtest("Test router connectivity to upstream"):
        client.wait_for_unit("network-online.target")
        router.succeed("curl --fail http://server/")

      with subtest("Test client ability to route through NAT"):
        client.succeed("curl --fail http://server/")
    '';
  };

  hosts = let ethernetAddress = "aa:bb:cc:dd:ee:ff";
  in pkgs.nixosTest {
    name = "router-hosts";
    nodes = {
      router = {
        imports = [ routerBase ];
        lab.router.network.hosts = [{
          ipAddress = "10.0.0.200";
          hostName = "le-host-name";
          inherit ethernetAddress;
        }];
      };

      client = {
        imports = [ clientBase ];
        networking.interfaces.eth1.macAddress = ethernetAddress;
      };
    };

    testScript = ''
      start_all()

      client.wait_for_unit("network-online.target")
      client.succeed("ip addr show eth1 | grep 10.0.0.200")
    '';
  };
}
