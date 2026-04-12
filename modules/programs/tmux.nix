{
  programs.tmux = {
    enable = true;
    shell = "/bin/zsh";
    terminal = "tmux-256color";
    prefix = "C-a";
    baseIndex = 1;
    mouse = true;
    keyMode = "vi";
    extraConfig = ''
      # ログインシェルで起動（starship等を読み込む）
      set -g default-command "zsh --login"

      # プレフィックス送信
      unbind C-b
      bind C-a send-prefix

      # ペイン分割を直感的に
      bind | split-window -h -c "#{pane_current_path}"
      bind '\' split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      unbind %
      unbind '"'

      # ペイン移動を vim 風に
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # ウィンドウを閉じたとき番号を詰める
      set -g renumber-windows on

      # ターミナルタイトルをセッション名に
      set -g set-titles on
      set -g set-titles-string "#S"
      set -g allow-passthrough on

      # ステータスバー (Tokyo Night — 背景はターミナルに透過)
      set -g status-position top
      set -g status-style "bg=default,fg=#c0caf5"
      set -g status-left "#[bg=#7aa2f7,fg=#1a1b26,bold] #S #[bg=default] "
      set -g status-right "#[fg=#7aa2f7]%H:%M"
      set -g window-status-current-style "bg=#33467c,fg=#c0caf5,bold"
      set -g window-status-style "fg=#414868"
      set -g pane-border-style "fg=#414868"
      set -g pane-active-border-style "fg=#7aa2f7"
      set -g message-style "bg=default,fg=#c0caf5"
    '';
  };
}
