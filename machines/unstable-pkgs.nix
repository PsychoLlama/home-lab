let
  nixpkgs =
    fetchTarball "https://github.com/NixOS/nixpkgs/archive/f225322e3b.tar.gz";

in import nixpkgs # Note: still expects a config argument.
