{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.lab.presets.programs.tmux;
in

{
  options.lab.presets.programs.tmux = {
    enable = lib.mkEnableOption "Use tmux";
  };

  config.programs.tmux = lib.mkIf cfg.enable {
    enable = true;
    package = pkgs.unstable.tmux;
    keyMode = "vi";
    focusEvents = true;

    extraConfig = ''
      # Keep the server alive even if all sessions are ended.
      set-option -g exit-empty off

      # Don't detatch if when killing the session.
      set-option -g detach-on-destroy off

      # Assume terminal emulator supports native clipboard integration.
      set-option -g set-clipboard on

      # Default behavior suspends the client. Nobody has ever wanted this.
      unbind-key C-z

      # Add vim-like keybindings to visual mode.
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi y send-keys -X copy-selection
      bind-key P paste-buffer

      # Default new panes/windows to the current directory.
      bind-key c new-window -c '#{pane_current_path}'
      bind-key '"' split-window -vc '#{pane_current_path}'
      bind-key % split-window -hc '#{pane_current_path}'
    '';
  };
}
