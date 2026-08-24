{
  flake = {
    nixosModules.nixos-platform = ../../platforms/nixos/modules;
    homeModules.home-manager-platform = ../../platforms/home-manager/modules;
  };
}
