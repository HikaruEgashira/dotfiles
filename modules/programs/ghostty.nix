{
  home.file.".config/ghostty/config" = {
    text = ''
      theme = TokyoNight

      maximize = true
      macos-titlebar-style = tabs
      window-inherit-working-directory = true
      window-vsync = true
      font-family = PlemolJP35 Console NF
      font-size = 13
      font-thicken = true
      adjust-cell-height = 2

      # `none` avoids ZDOTDIR hijacking that prevents .zshrc from loading
      shell-integration = none

      working-directory = /Users/hikae/ghq/github.com/HikaruEgashira
      desktop-notifications = true

      keybind = shift+enter=text:\n
      keybind = cmd+shift+d=text:claude\n

      # macOS-style shortcuts: forward cmd+key as raw bytes; nvim maps them per mode
      keybind = cmd+z=send_byte:0x1a
      keybind = cmd+c=send_byte:0x03
      keybind = cmd+v=send_byte:0x16
    '';
    force = true;
  };
}
