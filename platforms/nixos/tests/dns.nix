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
        config.services.etcd.package
        pkgs.dig
        pkgs.doggo
      ];

      # TODO: Manage service discovery in a separate and focused test.
      lab.services.discovery.server = {
        enable = true;
        dns = {
          zone = "dyn.example.com";
          prefix.name = "skydns";
        };
      };

      lab.services.dns = {
        enable = true;
        interfaces = [ "eth1" ];
        server.id = "magic-string-nsid";

        discovery = {
          enable = true;
          zones = [ config.lab.services.discovery.server.dns.zone ];
          dns.prefix = "/${config.lab.services.discovery.server.dns.prefix.name}";
        };

        # Test multiple zones with hierarchy (more specific zone takes precedence)
        zones = {
          # Wildcard zone for services - separate from discovery zone
          "services.test" = {
            records = [
              {
                type = "CNAME";
                name = "*";
                value = "ingress.services.test.";
              }
              {
                type = "A";
                name = "ingress";
                value = "192.168.1.1";
              }
            ];
          };

          # More specific zone takes precedence over parent wildcard
          "host.services.test" = {
            records = [
              {
                type = "TXT";
                name = "custom-record";
                value = "magic-string-record";
              }
            ];
          };
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

  testScript =
    # python
    ''
      import json

      start_all()
      machine.wait_for_unit("coredns.service")
      machine.wait_for_unit("etcd.service")
      machine.wait_for_unit("network-online.target")

      with subtest("NSID is advertised in responses"):
        nsid_line = machine.succeed("dig +nsid @localhost localhost | grep NSID")
        print(nsid_line)
        assert "magic-string-nsid" in nsid_line, "NSID not in response"

      with subtest("resolves custom records"):
        result = machine.succeed("doggo @localhost TXT custom-record.host.services.test")
        print(result)
        assert "magic-string-record" in result, "Custom record not in response"

      with subtest("uses local server as system DNS resolver"):
        # Not specifying the server address - pull from `/etc/resolv.conf`.
        result = machine.succeed("doggo TXT custom-record.host.services.test")
        print(result)
        assert "magic-string-record" in result, "Local server was not used"

      with subtest("serves records from the host file"):
        result = machine.succeed("doggo custom-host.arpa")
        print(result)
        assert "127.1.2.3" in result, "Record from host file was not found"

      with subtest("resolves dynamic hosts from etcd"):
        payload = json.dumps({ "host": "10.20.30.40", "ttl": 3600, "type": "A" })
        machine.succeed(f"etcdctl put /skydns/com/example/dyn/test '{payload}'")

        resolved = machine.succeed("doggo @localhost A test.dyn.example.com")
        print(resolved)
        assert "10.20.30.40" in resolved, "Dynamic record not in response"

      with subtest("wildcard zone resolves subdomains"):
        # The wildcard *.services.test should return a CNAME to ingress.services.test
        result = machine.succeed("doggo @localhost CNAME foo.services.test")
        print(result)
        assert "ingress.services.test." in result, "Wildcard CNAME not in response"

      with subtest("wildcard CNAME chain resolves to A record"):
        # Following the CNAME to ingress.services.test should resolve to an A record
        result = machine.succeed("doggo @localhost A foo.services.test")
        print(result)
        assert "192.168.1.1" in result, "Wildcard CNAME chain did not resolve to A record"

      with subtest("specific zone takes precedence over wildcard"):
        # host.services.test is more specific than services.test, so its records
        # should be served instead of the wildcard from services.test
        result = machine.succeed("doggo @localhost TXT custom-record.host.services.test")
        print(result)
        assert "magic-string-record" in result, "Specific zone did not take precedence"

      # No tests for DNS forwarding. Just try not to break it :)
    '';
}
