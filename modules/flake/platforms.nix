{
  flake = {
    nixosModules.nixos-platform = ../platforms/nixos;
    homeModules.home-manager-platform = ../platforms/home-manager;
  };
}
