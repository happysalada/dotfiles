{ lib, ... }:
let
  # SecuriteInfo's free set: nine files below one keyed path, so the prefix is
  # written once. The key is account-bound - a new one means editing this line.
  securiteInfo =
    file: "https://www.securiteinfo.com/get/signatures/80b7426e3b82a248c1db6abfea3daa32b9290fe6f52e17957061c70e520a120c799b280d5ae3730e82cfe652344eed5a3c10e9a9fe3497d60c0b201339012e6b/${file}";
in
{
  # Antivirus in three parts: clamd answers scans, freshclam keeps Cisco's
  # database, fangfrisch adds the third-party signature sets that never reach
  # the official mirror. What to scan and when stays in each machine's config -
  # a server's files and a laptop's Downloads do not want the same sweep.
  services.clamav = {
    daemon = {
      enable = true;
      # clamd's defaults (25M per file, 100M per scan) report anything larger
      # as clean rather than as unscanned, which is the wrong way to be wrong.
      settings = {
        MaxFileSize = "100M";
        MaxScanSize = "400M";
        AlertExceedsMax = true;
      };
    };

    updater = {
      enable = true;
      settings.DatabaseCustomURL = map securiteInfo [
        "securiteinfo.hdb"
        "securiteinfo.ign2"
        "javascript.ndb"
        "spam_marketing.ndb"
        "securiteinfohtml.hdb"
        "securiteinfoascii.hdb"
        "securiteinfoandroid.hdb"
        "securiteinfoold.hdb"
        "securiteinfopdf.hdb"
      ];

      # freshclam never gives up by default (ReceiveTimeout 0), and the switch
      # waits for it. A cap per file, not an idle timeout: 30 minutes is far
      # past the slowest healthy download seen (90 MB at ~360 KB/s).
      settings.ConnectTimeout = 30;
      settings.ReceiveTimeout = 1800;
    };

    fangfrisch = {
      # mkDefault, so a machine short on RAM can drop the extra signatures with
      # one `fangfrisch.enable = false;` of its own.
      enable = lib.mkDefault true;

      # The module turns urlhaus on by default, but abuse.ch answers 410 for
      # all of /downloads since at least 2026-10-22, so the hourly refresh
      # would fail on a feed that no longer exists. Sanesecurity needs no
      # account and still updates daily.
      settings.urlhaus.enabled = "no";
    };
  };

  # A oneshot has no start timeout, and clamd waits behind it, so a stalled
  # download would hold `nixos-rebuild switch` indefinitely.
  systemd.services.clamav-freshclam.serviceConfig.TimeoutStartSec = "45min";
}
