{ runTest, baseModule, lib, ... }:

{
  assignment = runTest {
    name = "assignment";
    imports = [ baseModule ];

    defaults.lab.networks.test.ipv4 = {
      cidr = "10.0.5.1/24";
      dhcp.ranges = [{
        start = "10.0.5.22";
        end = "10.0.5.22";
      }];
    };

    nodes = {
      server = { config, ... }: {
        virtualisation.vlans = [ 1 ];
        networking.useDHCP = false;

        lab.dhcp = {
          enable = true;
          networks.test.interface = "eth1";
        };

        assertions = [{
          assertion = lib.any (port: port == 67)
            config.networking.firewall.interfaces.eth1.allowedUDPPorts;

          message = ''
            DHCP server did not open firewall.
          '';
        }];
      };

      client = {
        # TODO
      };
    };

    testScript = ''
      start_all()

      server.wait_for_unit("network-online.target")
      server.shell_interact()
    '';
  };
}
