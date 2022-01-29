{
  description = "Hobbyist home lab";
  inputs.nixpkgs.url = "nixpkgs";

  outputs = { self, nixpkgs }:
    let
      defineHost = import ./machines/define-host.nix;
      hostDefinitions = with nixpkgs.lib;
        (mapAttrs (hostName: _: defineHost hostName)
          (filterAttrs (_: pathType: pathType == "directory")
            (builtins.readDir ./machines/hosts)));

    in {
      nixopsConfigurations = {
        default = hostDefinitions // {
          inherit nixpkgs;

          network = let inherit (import ./machines/config) domain;
          in {
            description = domain;
            enableRollback = true;
            storage.legacy.databasefile = "~/.nixops/deployments.nixops";
          };
        };
      };

      checks = with nixpkgs.lib;
        listToAttrs (forEach [ "x86_64-linux" "aarch64-linux" ] (system:
          nameValuePair system (import ./tests {
            pkgs = import ./machines/unstable-pkgs.nix { inherit system; };
          })));
    };
}
