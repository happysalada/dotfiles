{ pkgs }:
{
  i3status-rust = {
    enable = true;
  };
  
  rofi = {
    enable = true;  
    location = "center";
    plugins = with pkgs; [ rofi-calc ];
    font = "Fira Code 24";
    extraConfig = {
      modi = "window,drun,ssh,combi";
      combi-modi = "window,drun,run,ssh";
    };
  };
  
  xsession.windowManager.i3 = let
      fonts = {
        name = [ "Fira Code" "Font Awesome 5 Free"];
        style = "Bold Semi-Condensed";
        size = 16.0;
      };
  in
  {
    enable = true;  
    config = {
      assigns = {
        "1: slack"= [{ class = "^Slack$";}];
        "0: web"= [{ class = "google-chrome";}];
      };
      inherit fonts;
      menu = "${pkgs.rofi}/bin/rofi -show combi";
      window = {
        border = 0;  
        hideEdgeBorder = "both";
        titlebar = false;
      };
      workspaceAutoBackAndForth = true;
      bars = [{
        id = "default";
        mode = "dock";
        position = "top";
        statusCommand = "${pkgs.i3status-rust}/bin/i3status-rs";
        workspaceButtons = true;
        workspaceNumbers = true;
        colors = {
          background = "#000000";
          statusline = "#ffffff";
        };
        inherit fonts;
      }];
    };
  };
}