{ makeTest, ... }:

makeTest {
  name = "dns-lookup";

  nodes.machine =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      environment.systemPackages = [
        pkgs.dig
        pkgs.doggo
      ];

      lab.services.dns = {
        enable = true;
        interfaces = [ "eth1" ];
        server.id = "magic-string-nsid";

        zone = {
          name = "example.com";
          records = [
            {
              type = "TXT";
              name = "custom-record";
              value = "magic-string-record";
            }
          ];
        };

        hosts.file = pkgs.writeText "hosts" ''
          127.1.2.3  custom-host.arpa
        '';

        # These are not used, but it is important to test the generation
        # code paths to validate that at least the server does not crash.
        forward = [
          {
            zone = "non.existent.domain.one";
            method = "udp";
            udp.ip = "9.9.9.9";
          }
          {
            zone = "non.existent.domain.two";
            method = "resolv.conf";
          }
          {
            zone = ".";
            method = "tls";
            tls = {
              ip = "1.1.1.1";
              servername = "cloudflare-dns.com";
            };
          }
        ];
      };

      assertions = [
        {
          assertion = lib.any (port: port == 53) config.networking.firewall.interfaces.eth1.allowedUDPPorts;
          message = ''
            DNS server did not open firewall.
          '';
        }
      ];
    };

  testScript = ''
    start_all()
    machine.wait_for_unit("coredns.service")
    machine.wait_for_unit("network-online.target")

    with subtest("NSID is advertised in responses"):
      nsid_line = machine.succeed("dig +nsid @localhost localhost | grep NSID")
      print(nsid_line)
      assert "magic-string-nsid" in nsid_line, "NSID not in response"

    with subtest("resolves custom records"):
      result = machine.succeed("doggo @localhost TXT custom-record.example.com")
      print(result)
      assert "magic-string-record" in result, "Custom record not in response"

    with subtest("uses local server as system DNS resolver"):
      # Not specifying the server address - pull from `/etc/resolv.conf`.
      result = machine.succeed("doggo TXT custom-record.example.com")
      print(result)
      assert "magic-string-record" in result, "Local server was not used"

    with subtest("serves records from the host file"):
      result = machine.succeed("doggo custom-host.arpa")
      print(result)
      assert "127.1.2.3" in result, "Record from host file was not found"

    # No tests for DNS forwarding. Just try not to break it :)
  '';
}
