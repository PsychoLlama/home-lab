{ config, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      # Export node data as JSON for Terraform consumption
      packages.terraform-config = pkgs.callPackage ../../pkgs/terraform-config {
        inherit (config.flake.colmenaHive) nodes;
      };
    };
}
