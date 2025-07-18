{ makeTest, lib, ... }:

makeTest {
  name = "dhcp-assignment";

  defaults.lab.networks.test.ipv4 = {
    cidr = "10.0.5.3/24";
    dhcp.pools = [
      {
        start = "10.0.5.22";
        end = "10.0.5.22";
      }
    ];
  };

  nodes = {
    server =
      { config, ... }:
      {
        virtualisation.vlans = [ 1 ];
        networking.useDHCP = false;

        lab.services.dhcp = {
          enable = true;
          networks.test.interface = "eth1";
          nameservers = [ config.lab.networks.test.ipv4.gateway ];
          reservations = [
            rec {
              type = "client-id";
              ip-address = "10.0.5.68";
              id = config.lab.services.dhcp.lib.toClientId ip-address;
            }
          ];
        };

        assertions = [
          {
            assertion = lib.any (port: port == 67) config.networking.firewall.interfaces.eth1.allowedUDPPorts;

            message = ''
              DHCP server did not open firewall.
            '';
          }
        ];

        systemd.network = {
          enable = true;
          networks = {
            "01-eth1" = {
              name = "eth1";
              networkConfig.Address = "10.0.5.11/24";
            };
          };
        };
      };

    client = {
      virtualisation.vlans = [ 1 ];
      systemd.services.systemd-networkd = {
        environment.SYSTEMD_LOG_LEVEL = "debug";
      };

      networking = {
        useNetworkd = true;
        useDHCP = false;
        interfaces.eth1.useDHCP = true;
      };
    };

    reserved =
      { config, ... }:
      {
        virtualisation.vlans = [ 1 ];

        networking = {
          useDHCP = false;
          interfaces.eth1.useDHCP = true;

          dhcpcd.extraConfig = ''
            clientid ${config.lab.services.dhcp.lib.toClientId "10.0.5.68"}
          '';
        };
      };
  };

  testScript = ''
    import json

    server.start()
    client.start()

    server.wait_for_unit("kea-dhcp4-server.service")

    with subtest("correct client IP is assigned"):
      client.wait_until_succeeds("ip addr show eth1 | grep -q '10.0.5.22/24'")

    with subtest("default gateway is assigned"):
      routes = json.loads(client.succeed("ip --json route"))
      gateways = {
        route["gateway"] for route in routes
        if (
          route["dev"] == "eth1" and
          route["protocol"] == "dhcp" and
          "gateway" in route
        )
      }

      assert "10.0.5.3" in gateways, f"Gateway was not assigned: {gateways}"

    with subtest("expected DNS servers are provided"):
      client.succeed("resolvectl dns eth1 | grep -q '10.0.5.3'")

    with subtest("reservations are given to recognized hosts"):
      reserved.start()
      reserved.wait_until_succeeds("ip addr show eth1 | grep -q '10.0.5.68/24'")
  '';
}
