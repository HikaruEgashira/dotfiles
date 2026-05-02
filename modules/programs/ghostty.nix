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

      # cmd+* → tmux prefix (C-a, \x01) + key
      keybind = cmd+t=text:\x01c
      keybind = cmd+w=text:\x01x
      keybind = cmd+n=text:\x01n
      keybind = cmd+p=text:\x01p
      keybind = cmd+comma=text:\x01,

      keybind = cmd+one=text:\x011
      keybind = cmd+two=text:\x012
      keybind = cmd+three=text:\x013
      keybind = cmd+four=text:\x014
      keybind = cmd+five=text:\x015
      keybind = cmd+six=text:\x016
      keybind = cmd+seven=text:\x017
      keybind = cmd+eight=text:\x018
      keybind = cmd+nine=text:\x019

      keybind = cmd+d=text:\x01\
      keybind = cmd+backslash=text:\x01\
      keybind = cmd+shift+minus=text:\x01-

      keybind = cmd+h=text:\x01h
      keybind = cmd+j=text:\x01j
      keybind = cmd+k=text:\x01k
      keybind = cmd+l=text:\x01l

      keybind = cmd+z=text:\x01z
    '';
    force = true;
  };
}
