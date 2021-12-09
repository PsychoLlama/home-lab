rec {
  domain = "selfhosted.city";
  defineHost = path:
    { config, lib, pkgs, ... }:
    let unstable = import ./unstable-pkgs.nix { system = pkgs.system; };

    in {
      imports = [
        ./services/service-mesh.nix
        ./services/container-orchestration.nix
        path
      ];

      # Run garbage collection on a schedule.
      nix.gc.automatic = true;

      # Match the directory name to the host's name.
      networking.hostName = lib.mkDefault (baseNameOf path);

      # Assume all hosts exist under the root domain.
      networking.domain = domain;

      deployment = { targetHost = "${config.networking.hostName}.${domain}"; };

      # Enable flakes.
      nix = {
        package = unstable.nix;
        extraOptions = ''
          experimental-features = nix-command flakes
        '';
      };

      services.openssh = {
        enable = true;
        passwordAuthentication = false;
      };

      users.users.root.openssh.authorizedKeys.keyFiles =
        [ ./keys/deploy.pub ./keys/admin.pub ];
    };
}
