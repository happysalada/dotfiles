{ config, lib, pkgs, ... }:

{
  services.gitea = {
    enable = true;
    database = {
      type = "postgres";
      createDatabase = true;
      socket = "/var/run/postgresql";
    };
    domain = "git.union.rocks";
    rootUrl = "https://git.union.rocks";
    httpPort = 3030;
    httpAddress = "127.0.0.1";
    cookieSecure = true;
    ssh.enable = true;
    settings = {
      repository = {
        PREFERRED_LICENSES = "AGPL-3.0,GPL-3.0,GPL-2.0,LGPL-3.0,LGPL-2.1";
      };

      mailer = {
        ENABLED = true;
        MAILER_TYPE = "sendmail";
        FROM = "yt@union.rocks";
        SENDMAIL_PATH = "${pkgs.system-sendmail}/bin/sendmail";
        # SUBJECT = "%(APP_NAME)s";
        # HOST = "petabyte.dev:465";
        # USER = "gitea@union.rocks";
        # SEND_AS_PLAIN_TEXT = true;
        # USE_SENDMAIL = false;
        # FROM = "\"PetaByteBoy's Gitea\" <gitea@petabyte.dev>";
      };

      picture = {
        DISABLE_GRAVATAR = true;
      };

      attachment = {
        ALLOWED_TYPES = "*/*";
      };

      service = {
        REGISTER_EMAIL_CONFIRM = true;
        ENABLE_NOTIFY_MAIL = true;
        ENABLE_CAPTCHA = true;
        NO_REPLY_ADDRESS = "union.rocks";
      };

      ui = {
        THEMES = "gitea,arc-green,pitchblack";
        DEFAULT_THEME = "pitchblack";
      };
    };
  };

  systemd.services.gitea.serviceConfig.ExecStartPre = [
    "${pkgs.coreutils}/bin/mkdir -p /var/lib/gitea/custom/public/assets/css"
    "${pkgs.coreutils}/bin/ln -sfT ${pkgs.runCommand "gitea-public" {
      buildInputs = with pkgs; [ rsync ];
    } ''
      rsync -a ${pkgs.fetchgit {
        url = "https://github.com/iamdoubz/Gitea-Pitch-Black";
        rev = "38a10947254e46a0a3c1fb90c617d913d6fe63b9";
        sha256 = "sha256-iIygxSrI6FLdNJIZl44daMOlnP9CSOVFcTZNAsGW9f4=";
      }}/theme-pitchblack.css $out/
    ''}/theme-pitchblack.css /var/lib/gitea/custom/public/assets/css/theme-pitchblack.css"
  ];

  services.caddy.virtualHosts."git.union.rocks" = {
    extraConfig = ''
      reverse_proxy 127.0.0.1:${toString config.services.gitea.httpPort}
    '';
  };
}