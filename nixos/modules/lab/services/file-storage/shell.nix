{ pkgs ? import <nixpkgs> { } }:

# This file is only used for developing the zfs_attrs.py script.

pkgs.mkShell {
  packages = [
    (pkgs.python3.withPackages (p: [ p.termcolor ]))
    pkgs.python3Packages.black
    pkgs.viddy

    (pkgs.writers.writeNuBin "unit-test" ''
      use ${pkgs.nushell.src}/crates/nu-std/testing.nu run-tests
      run-tests
    '')

    (pkgs.writers.writeNuBin "unit-test-watch" ''
      watch . --glob=**/*.nu {
        clear
        unit-test
      }
    '')
  ];

  shellHook = ''
    format() {
      black zfs_attrs.py --line-length 78 # Enforced by PEP8 E501
    }

    unit_test() {
      viddy -n 0.5 python3 -m unittest zfs_attrs
    }
  '';
}
