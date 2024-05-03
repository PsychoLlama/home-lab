# ONLY USED FOR LOCAL DEVELOPMENT.

{
  inputs.call-flake.url = "github:divnix/call-flake";

  outputs =
    { self, call-flake }:
    # The `call-flake` pattern allows us to extend the parent flake without
    # pinning it to a specific revision. It's all in the same git repo, after
    # all.
    #
    # For more details:
    # https://figsoda.github.io/posts/2023/developing-nix-libraries-with-subflakes/
    let
      inherit (call-flake ../../../../..) lib;
    in
    {
      devShell = lib.eachSystem (
        system: pkgs:
        pkgs.mkShell {
          EXPECTED_STATE = "./state-file.json";

          packages = [
            (pkgs.unstable.writers.writeNuBin "unit-test" ''
              use ${pkgs.unstable.nushell.src}/crates/nu-std/testing.nu run-tests
              run-tests
            '')

            (pkgs.unstable.writers.writeNuBin "unit-test-watch" ''
              unit-test
              watch . --glob=*propctl.nu {
                clear
                unit-test
              }
            '')
          ];
        }
      );
    };
}
