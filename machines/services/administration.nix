{ config, lib, pkgs, ... }:

let cfg = config.lab.administration;

in with lib; {
  options.lab.administration.enable = mkEnableOption "Enable admin toolchain";

  config = mkIf cfg.enable {
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

      setOptions = [
        "auto_cd"
        "auto_pushd"
        "hist_ignore_all_dups"
        "hist_ignore_space"
        "hist_no_functions"
        "hist_reduce_blanks"
        "interactive_comments"
        "pipefail"
        "pushd_ignore_dups"
        "share_history"
      ];
    };

    users = {
      groups.pantheon = { };
      users.admin = {
        description = "Server administrator";
        extraGroups = [ "wheel" "pantheon" "docker" "keys" ];
        isNormalUser = true;
        packages = [ pkgs.starship ];
        shell = pkgs.zsh;

        openssh.authorizedKeys.keyFiles = [ ../keys/admin.pub ];
      };
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
  };
}
