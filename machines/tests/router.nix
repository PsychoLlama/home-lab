{ pkgs ? import ../unstable-pkgs.nix { } }:

{
  basic = pkgs.nixosTest {
    name = "router-basic";
    nodes = {
      router = {
        imports = [ ../services/router.nix ];
        virtualisation.vlans = [ 1 2 ];
        networking.interfaces.eth1.useDHCP = false;

        lab.router = {
          enable = true;
          network.wan.interface = "eth1";
          network.lan.interface = "eth2";
        };
      };

      client = {
        virtualisation.vlans = [ 2 ];
        networking = {
          useDHCP = false;
          interfaces.eth1.useDHCP = true;
        };
      };
    };

    testScript = ''
      start_all()

      client.wait_for_unit('network-online.target')
      client.succeed('ip addr show eth1 to 10.0.0.1/24 | grep inet')
    '';
  };
}
