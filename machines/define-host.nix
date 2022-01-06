# Creates a top-level NixOS config, applied to all machines in the home lab.
# This is responsible for setting the baseline configuration.

let inherit (import ./config.nix) domain;

in hostPath:
{ config, lib, pkgs, ... }:
let unstable = import ./unstable-pkgs.nix { system = pkgs.system; };

in {
  imports = [ ./services hostPath ];

  # Match the directory name to the host's name.
  networking.hostName = lib.mkDefault (baseNameOf hostPath);

  # All hosts are addressed as `{host}.host.{domain}`.
  networking.domain = "host.${domain}";

  deployment.targetHost = config.networking.fqdn;

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
}
