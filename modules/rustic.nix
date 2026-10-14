# Offsite backups to Backblaze B2 with rustic. Not modules/restic.nix, which is
# the same job over Cloudflare R2 and is parked with its secrets - the two are
# separate tools (rustic is a restic-compatible rewrite) and must not be
# imported together.
#
# Backed by opendal's native `b2` service, so the only credentials rustic needs
# are a B2 application key and the repository password; both are agenix secrets.
# The key id / key / bucket id are not in the config file at all - they are
# read from the process environment as RUSTIC_REPO_OPT_* vars, which opendal
# merges into [repository.options] (verified with `rustic show-config`).
#
# The timer arms the RTC (WakeSystem) so a suspended laptop wakes at midnight,
# backs up, and is free to suspend again. A machine that is fully *off* at
# midnight cannot be woken from S5 by an RTC alarm on this hardware - Persistent
# catches that run up at the next boot instead.
{ config, lib, pkgs, ... }:
let
  bucket = "megzari-strix-backups";
  root = "strix"; # subdir in the bucket, so other machines can share it later

  backupPaths = [ "/home" ];

  # gitignore-style globs: patterns exclude, a `!` prefix would re-include.
  excludes = [
    "**/.cache/**"
    "**/.local/share/Trash/**"
    "**/node_modules/**"
    "**/target/**"
    "**/.venv/**"
    "**/__pycache__/**"
    "**/.direnv/**"
  ];

  rusticConfig = ''
    [repository]
    repository = "opendal:b2"
    password-file = "${config.age.secrets.rustic-password.path}"
    cache-dir = "/var/cache/rustic"

    [repository.options]
    bucket = "${bucket}"
    root = "${root}"

    [backup]
    globs = ${builtins.toJSON excludes}

    [forget]
    prune = true
    keep-daily = 14
    keep-weekly = 8
    keep-monthly = 6
  '';
in
{
  age.secrets = {
    rustic-password.file = ../secrets/rustic.password.age;
    b2-credentials.file = ../secrets/b2.credentials.age;
  };

  environment.etc."rustic/rustic.toml".text = rusticConfig;

  systemd.tmpfiles.rules = [ "d /var/cache/rustic 0755 root root -" ];

  systemd.services.rustic-backup = {
    description = "Offsite backup to Backblaze B2";
    serviceConfig = {
      Type = "oneshot";
      # The B2 application key id / key / bucket id live here as
      # RUSTIC_REPO_OPT_APPLICATION_KEY_ID / _APPLICATION_KEY / _BUCKET_ID.
      EnvironmentFile = config.age.secrets.b2-credentials.path;
      # rustic reads <config-dir>/rustic/rustic.toml; environment.etc above
      # puts it at /etc/rustic/rustic.toml.
      Environment = "XDG_CONFIG_HOME=/etc";
      # a backup must never compete with whatever is awake
      Nice = 19;
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
    };
    script = ''
      ${pkgs.rustic}/bin/rustic backup --init ${lib.escapeShellArgs backupPaths}
      ${pkgs.rustic}/bin/rustic forget
    '';
  };

  systemd.timers.rustic-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00:00:00";
      Persistent = true;
      WakeSystem = true;
    };
  };
}
