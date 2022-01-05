rec {
  domain = "selfhosted.city";
  defineHost = path:
    { config, lib, pkgs, ... }:
    let unstable = import ./unstable-pkgs.nix { system = pkgs.system; };

    in {
      imports = [ ./services path ];

      # Match the directory name to the host's name.
      networking.hostName = lib.mkDefault (baseNameOf path);

      # Assume all hosts exist under the root domain.
      networking.domain = domain;

      deployment = {
        targetHost = "${config.networking.hostName}.host.${domain}";
      };

      # Enable flakes.
      nix = {
        # Run garbage collection on a schedule.
        gc.automatic = true;

        # Use hard links to save disk space.
        optimise.automatic = true;

        package = unstable.nix;
        extraOptions = ''
          experimental-features = nix-command flakes
        '';
      };

      services.openssh = {
        enable = true;
        passwordAuthentication = false;
      };

      programs.zsh = {
        enable = true;
        syntaxHighlighting.enable = true;
        autosuggestions.enable = true;
        histSize = 500;
        promptInit = ''
          eval "$(starship init zsh)"
        '';
      };

      users = {
        groups.pantheon = { };
        users.admin = {
          description = "Server administrator";
          extraGroups = [ "wheel" "pantheon" "docker" ];
          isNormalUser = true;
          packages = [ pkgs.starship ];

          openssh.authorizedKeys.keyFiles = [ ./keys/admin.pub ];
        };

        defaultUserShell = pkgs.zsh;
      };

      # Passwords are for programs. The Law has entered the game.
      # https://www.youtube.com/watch?v=pEHZLcFMVo0&t=130s
      security.sudo.extraRules = [{
        groups = [ "pantheon" ];
        commands = [{
          command = "ALL";
          options = [ "NOPASSWD" ];
        }];
      }];

      users.users.root.openssh.authorizedKeys.keyFiles = [ ./keys/deploy.pub ];
    };
}
