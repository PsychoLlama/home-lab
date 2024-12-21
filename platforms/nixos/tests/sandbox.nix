{ makeTest, ... }:

makeTest {
  name = "sandbox-environment";

  nodes.machine =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.hello ];
    };

  testScript = ''
    start_all()
    machine.shell_interact()
  '';
}
