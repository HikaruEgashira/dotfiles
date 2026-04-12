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

      # ステータスバー
      set -g status-position top
      set -g status-style "bg=default,fg=white"
      set -g status-left "[#S] "
      set -g status-right "%H:%M"
    '';
  };
}
