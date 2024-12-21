{ makeTest, ... }:

let
  wan-vlan-id = 1;
  lan-vlan-id = 2;
  ip = {
    client = "10.60.5.10";
    world = "192.168.65.0";
    g8w_wan = "192.168.65.10";
    g8w_lan = "10.60.5.0";
  };
in

makeTest {
  name = "gateway";

  defaults.lab.networks = {
    lan.ipv4.cidr = "${ip.g8w_lan}/24";
    wan.ipv4 = {
      cidr = "${ip.world}/24";
      dhcp.pools = [
        {
          start = ip.g8w_wan;
          end = ip.g8w_wan;
        }
      ];
    };
  };

  nodes = {
    # `world` exists on the outer network segment.
    world =
      { config, ... }:

      let
        inherit (config.lab.networks) wan;
      in

      {
        services.httpd.enable = true;
        networking.firewall.allowedTCPPorts = [ 80 ];
        virtualisation.vlans = [ wan-vlan-id ];
        networking.interfaces.eth1.ipv4.addresses = [
          {
            address = wan.ipv4.gateway;
            prefixLength = wan.ipv4.prefixLength;
          }
        ];

        lab.services.dhcp = {
          enable = true;
          networks.wan.interface = "eth1";
        };
      };

    # `gateway` bridges between the outer and inner network segments.
    gateway =
      { config, lib, ... }:
      {
        services.openssh.enable = true;
        virtualisation.vlans = [
          wan-vlan-id
          lan-vlan-id
        ];

        lab.services.gateway = {
          enable = true;
          wan.interface = "eth1";
          networks.lan.interface = "eth2";
        };
      };

    # `client` exists on the inner network segment.
    client =
      { config, ... }:
      {
        virtualisation.vlans = [ lan-vlan-id ];
        services.httpd.enable = true;
        networking.firewall.allowedTCPPorts = [ 80 ];

        networking = {
          defaultGateway = {
            address = config.lab.networks.lan.ipv4.gateway;
            interface = "eth1";
          };

          interfaces.eth1.ipv4.addresses = [
            {
              address = ip.client;
              prefixLength = 24;
            }
          ];
        };
      };
  };

  testScript = ''
    import json

    world.start()
    client.start()

    world.wait_for_unit("network-online.target")
    world.wait_for_unit("httpd.service")

    client.wait_for_unit("network-online.target")
    client.wait_for_unit("httpd.service")

    # This makes sure there's no magic in the test that allows the client and
    # outside world to communicate directly.
    with subtest("client cannot reach world without gateway"):
      client.fail("curl --fail --connect-timeout 2 http://${ip.world}")

    gateway.start()
    gateway.wait_for_unit("network-online.target")
    gateway.wait_for_unit("sshd.service")

    with subtest("preflight checks"):
      world.succeed("curl --fail http://localhost")

      # Same network. If this fails, it implies a firewall issue on the "world".
      gateway.succeed("curl --fail http://${ip.world}")
      gateway.succeed("curl --fail http://${ip.client}")

      client.succeed("ping -c 1 ${ip.g8w_lan}")

    with subtest("gateway was assigned correct IP address"):
      result = json.loads(gateway.succeed("ip --json addr show eth1"))
      gateway_wan_ip = result[0]["addr_info"][1]["local"]

      print(f"Gateway WAN IP: {gateway_wan_ip}")
      assert gateway_wan_ip == "${ip.g8w_wan}", "Gateway has wrong WAN IP"

    with subtest("client can communicate through the gateway"):
      gateway.succeed("curl --fail http://${ip.world}")

    with subtest("SSH is not open to the world"):
      world.fail("nc -w 1 -z ${ip.g8w_wan} 22")

    with subtest("SSH is open on the LAN"):
      client.succeed("nc -w 1 -z ${ip.g8w_lan} 22")

    with subtest("outside world cannot reach the client"):
      # Requests from the outside should fail.
      world.fail("curl --fail --connect-timeout 2 http://${ip.client}")
  '';
}
