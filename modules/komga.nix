# Komga: comics/manga server for the family. Public at https://comic.megzari.com
# through the Cloudflare tunnel (modules/fundies-tunnel.nix), which dials
# 127.0.0.1, so no port is open to the internet or to the LANs this laptop
# joins. Clients: the web UI, Komelia or Mihon.
#
# The library lives in a Backblaze B2 bucket mounted at /srv/comics, so the disk
# only holds a capped read/write cache. `cp` into the mount and it uploads. Every
# file shows as root-owned; rclone does not enforce the modes, so any user can write.
# The unit sets ProtectHome, so keep the library out of /home.
#
# The mount needs secrets/b2-comics.credentials.age, two lines:
# RCLONE_B2_ACCOUNT=<keyID> and RCLONE_B2_KEY=<applicationKey>, from a key scoped to
# the bucket (`agenix -e b2-comics.credentials.age` from secrets/). Until it exists
# Komga reads a plain local /srv/comics.
{ config, lib, pkgs, ... }:
let
  credentials = ../secrets/b2-comics.credentials.age;
  mountPoint = "/srv/comics";
  bucket = "megzari-comics";
in
{
  config = lib.mkMerge [
    {
      services.komga = {
        enable = true;
        settings.server.address = "127.0.0.1";
        # Komga's default 8080 is the fundies Caddy.
        settings.server.port = 10001;
      };
      systemd.tmpfiles.rules = [ "d ${mountPoint} 2775 yt komga -" ];
    }

    (lib.mkIf (builtins.pathExists credentials) {
      age.secrets.b2-comics.file = credentials;

      systemd.services.komga = {
        requires = [ "comics-mount.service" ];
        after = [ "comics-mount.service" ];
      };

      systemd.services.comics-mount = {
        description = "B2 bucket ${bucket} mounted at ${mountPoint}";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        path = [ "/run/wrappers" ]; # fusermount3

        serviceConfig = {
          Type = "notify";
          EnvironmentFile = config.age.secrets.b2-comics.path;
          CacheDirectory = "rclone-comics";
          Restart = "on-failure";
          RestartSec = "10s";
          ExecStart = lib.concatStringsSep " " [
            "${pkgs.rclone}/bin/rclone mount :b2:${bucket} ${mountPoint}"
            "--allow-other --file-perms 0664 --dir-perms 0775"
            "--cache-dir /var/cache/rclone-comics"
            # Bounds the disk use: files are fetched whole on read, evicted oldest first.
            "--vfs-cache-mode full --vfs-cache-max-size 3G --vfs-cache-max-age 1h"
          ];
          ExecStop = "/run/wrappers/bin/fusermount3 -uz ${mountPoint}";
        };
      };
    })
  ];
}
