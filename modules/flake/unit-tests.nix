{
  config,
  inputs,
  lib,
  ...
}:

let
  root = ../..;

  # Handed to every test file. Shared test helpers go here.
  context = {
    inherit lib;
    inherit (config) flake;
  };

  # Tests live beside the file they cover: `foo.nix` is tested by
  # `foo.test.nix`.
  testFiles = lib.pipe inputs.import-tree [
    (it: it.match ".*\\.test\\.nix")
    (it: it.leaves (root + "/modules"))
  ];

  # Keyed by the test file's path from the repo root, so nix-unit reports
  # failures as `<path>.<case>`.
  testName = file: lib.removePrefix "./" (lib.path.removePrefix root file);
in

{
  # The unit test suite as data, for `nix-unit --flake .#libTests`.
  flake.libTests = lib.listToAttrs (
    lib.map (file: lib.nameValuePair (testName file) (import file context)) testFiles
  );
}
