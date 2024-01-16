{ nixosTest, hello }:

{
  assignment = nixosTest {
    name = "assignment";
    nodes.client.environment.systemPackages = [ hello ];

    testScript = ''
      start_all()

      client.wait_for_unit("network-online.target")
      client.succeed("hello")
    '';
  };
}
