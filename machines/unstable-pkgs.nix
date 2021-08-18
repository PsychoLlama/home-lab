let
  nixpkgs =
    fetchTarball "https://github.com/NixOS/nixpkgs/archive/19c3ab9.tar.gz";

in import nixpkgs # Note: still expects a config argument.
