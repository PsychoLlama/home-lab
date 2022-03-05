{ pkgs ? import ../machines/unstable-pkgs.nix { } }:

let
  inherit (import ../machines/config) domain;
  routerBase = {
    imports = [ ./services ];
    virtualisation.vlans = [ 1 2 ];
    networking.interfaces.eth1.useDHCP = false;
    services.openssh.enable = true;

    lab.router = {
      enable = true;
      debugging.enable = true;
      network.wan.interface = "eth1";
      network.lan.interface = "eth2";
    };
  };

  clientBase = {
    imports = [ ./services ];
    virtualisation.vlans = [ 2 ];
    environment.systemPackages = [ pkgs.dogdns ];
    networking = {
      useDHCP = false;
      interfaces.eth1.useDHCP = true;
    };
  };

  consulBase = let ethernetAddress = "ee:ee:ee:ff:ff:ff";
  in { config, ... }: {
    imports = [ clientBase ];
    networking = {
      interfaces.eth1.macAddress = ethernetAddress;
      inherit domain;
    };

    lab = {
      consul = {
        interface = "eth1";
        server.enable = true;
        tls.enable = false;
        enable = true;
      };

      network = {
        inherit ethernetAddress;
        ipAddress = "10.0.0.205";
      };
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
        alice.succeed("nc -zvw 5 10.0.0.1 22")

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
        imports = [ ./services ];
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
      router = routerBase;
      client = {
        imports = [ clientBase ];
        networking.interfaces.eth1.macAddress = ethernetAddress;
        lab.network = {
          ipAddress = "10.0.0.200";
          inherit ethernetAddress;
        };
      };
    };

    testScript = ''
      start_all()

      client.wait_for_unit("network-online.target")
      client.succeed("ip addr show eth1 | grep 10.0.0.200")
    '';
  };

  dns = let ethernetAddress = "aa:bb:cc:dd:ee:ff";
  in pkgs.nixosTest {
    name = "router-dns";
    nodes = {
      router = {
        imports = [ routerBase ];
        lab.router.network.extraHosts = [{
          ipAddress = "10.0.0.234";
          hostName = "unmanaged";
          ethernetAddress = "bb:bb:bb:ee:ee:ee";
        }];

        lab.router.dns.records = [{
          name = "@";
          kind = "A";
          addresses = [ "127.0.0.2" ];
        }];
      };

      client = {
        imports = [ clientBase ];
        networking = {
          interfaces.eth1.macAddress = ethernetAddress;
          inherit domain;
        };

        lab.network = {
          ipAddress = "10.0.0.123";
          inherit ethernetAddress;
        };
      };

      consul = consulBase;
    };

    testScript = ''
      start_all()

      with subtest("Test basic functionality from router"):
        router.wait_for_unit("coredns.service")
        router.wait_for_open_port(53)
        router.succeed("dog @localhost localhost")

      with subtest("Test basic functionality from client"):
        client.wait_for_unit("network-online.target")
        client.succeed("dog @10.0.0.1 localhost")

      with subtest("Test custom host records"):
        client.succeed("dog @10.0.0.1 client.host.${domain} | grep 10.0.0.123")
        client.succeed("dog @10.0.0.1 unmanaged.host.${domain} | grep 10.0.0.234")

      with subtest("Test Consul service query forwarding"):
        consul.wait_for_open_port(8600)
        client.wait_until_fails(
          "dog @10.0.0.1 consul.service.lab.${domain} | grep -i nxdomain"
        )

      with subtest("Test custom service records"):
        client.succeed("dog @10.0.0.1 dns.${domain} | grep 10.0.0.1")
        client.succeed("dog @10.0.0.1 ${domain} | grep 127.0.0.2")
    '';
  };
}
