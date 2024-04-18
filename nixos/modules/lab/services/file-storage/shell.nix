{ pkgs ? import <nixpkgs> { } }:

# This file is only used for developing the zfs_attrs.py script.

pkgs.mkShell {
  packages = [ pkgs.python3 pkgs.python3Packages.black ];
  shellHook = ''
    format() {
      black zfs_attrs.py --line-length 78 # Enforced by PEP8 E501
    }

    unit_test() {
      python3 -m unittest zfs_attrs
    }
  '';
}
