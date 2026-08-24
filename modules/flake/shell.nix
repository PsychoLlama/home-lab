{ inputs, ... }:

{
  perSystem =
    { pkgs, system, ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          inputs.agenix.packages.${system}.default
          inputs.colmena.packages.${system}.colmena
          pkgs.unstable.just
          pkgs.unstable.mcp-grafana
          pkgs.unstable.nixVersions.latest
          pkgs.unstable.nixfmt
          pkgs.unstable.opentofu
          pkgs.unstable.treefmt
        ];
      };
    };
}
