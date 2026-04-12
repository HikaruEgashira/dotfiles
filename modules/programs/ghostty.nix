{
  # Ghostty terminal configuration
  # cmd+* keybindings are bridged to tmux prefix (C-a = \x01) commands
  home.file.".config/ghostty/config" = {
    text = ''
      # Theme
      theme = TokyoNight

      # Window settings
      maximize = true
      macos-titlebar-style = tabs
      window-inherit-working-directory = true
      background-opacity = 0.8

      # Font settings
      font-family = PlemolJP35 Console NF
      font-size = 13
      font-thicken = true
      adjust-cell-height = 2

      # Shell integration
      shell-integration = detect

      # Initial working directory
      working-directory = /Users/hikae/ghq/github.com/HikaruEgashira
      desktop-notifications = true

      # Ghostty native
      keybind = shift+enter=text:\n
      keybind = cmd+shift+d=text:claude\n

      # tmux bridge: cmd+* → prefix (C-a) + key
      # ウィンドウ操作
      keybind = cmd+t=text:\x01c
      keybind = cmd+w=text:\x01x
      keybind = cmd+n=text:\x01n
      keybind = cmd+p=text:\x01p
      keybind = cmd+comma=text:\x01,

      # ウィンドウ切替 (cmd+1..9)
      keybind = cmd+one=text:\x011
      keybind = cmd+two=text:\x012
      keybind = cmd+three=text:\x013
      keybind = cmd+four=text:\x014
      keybind = cmd+five=text:\x015
      keybind = cmd+six=text:\x016
      keybind = cmd+seven=text:\x017
      keybind = cmd+eight=text:\x018
      keybind = cmd+nine=text:\x019

      # ペイン分割
      keybind = cmd+d=text:\x01\
      keybind = cmd+backslash=text:\x01\
      keybind = cmd+shift+minus=text:\x01-

      # ペイン移動 (vim風)
      keybind = cmd+h=text:\x01h
      keybind = cmd+j=text:\x01j
      keybind = cmd+k=text:\x01k
      keybind = cmd+l=text:\x01l

      # ペインズーム
      keybind = cmd+z=text:\x01z
    '';
    force = true;
  };
}
