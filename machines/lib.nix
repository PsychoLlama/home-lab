rec {
  domain = "selfhosted.city";
  defineHost = path: { config, lib, pkgs, ... }: {
    imports = [
      ./services/service-mesh.nix
      path
    ];

    # Run garbage collection on a schedule.
    nix.gc.automatic = true;

    # Match the directory name to the host's name.
    networking.hostName = lib.mkDefault (baseNameOf path);

    # Assume all hosts exist under the root domain.
    networking.domain = domain;

    deployment = {
      targetHost = "${config.networking.hostName}.${domain}";
    };

    services.openssh = {
      enable = true;
      passwordAuthentication = false;
    };

    users.users.root.openssh.authorizedKeys.keyFiles = [
      ./keys/deploy.pub
      ./keys/admin.pub
    ];
  };
}
