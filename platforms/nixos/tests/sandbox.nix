{ makeTest, ... }:

makeTest {
  name = "sandbox-environment";

  nodes.machine =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.hello ];
    };

  testScript =
    # python
    ''
      start_all()
      machine.shell_interact()
    '';
}
