{ pkgs, ... }:

shell: {
  EXPECTED_STATE = "./state-file.json";

  nativeBuildInputs = shell.nativeBuildInputs ++ [
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
