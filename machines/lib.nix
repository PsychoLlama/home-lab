rec {
  domain = "selfhosted.city";
  defineHost = path: { config, lib, pkgs, ... }: {
    imports = [path];

    # Run garbage collection on a schedule.
    nix.gc.automatic = true;

    # Match the directory name to the host's name.
    networking.hostName = lib.mkDefault (baseNameOf path);

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
