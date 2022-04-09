{ config, lib, pkgs, ... }:

{
  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.caddy = {
    enable = true;
    # ca = "https://acme-staging-v02.api.letsencrypt.org/directory"; # comment once tested
    email = "raphael@megzari.com";
    extraConfig = ''
      (ban_bot) {
        @bot {
          path *.php */wp-includes/* */wp-content/* */cgi-bin/* *.asp *.aspx *.ini *.cgi *.xhtml *.log
        }
        respond @bot "FU" 1020 {
          close
        }
      }
      (static_assets) {
        @static_assets {
          path *.png /images/* /css/* /js/* /fonts/*
        }
      }

      larbimegzari.fr www.larbimegzari.fr {
        root * /etc/larbimegzari
        file_server
      }
    '';
  };
}