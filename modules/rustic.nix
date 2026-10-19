# Offsite backups to Backblaze B2 with rustic. Not modules/restic.nix, which is
# the same job over Cloudflare R2 and is parked with its secrets - the two are
# separate tools (rustic is a restic-compatible rewrite) and must not be
# imported together.
#
# Backed by opendal's native `b2` service, so the only credentials rustic needs
# are a B2 application key and the repository password; both are agenix secrets.
#
# The credentials cannot come from the environment. rustic 0.11 reads repository
# options only from the config file's [repository.options] table -
# `RUSTIC_REPO_OPT_*` is not read at all, `--option` does not exist, and opendal
# refuses to build the `b2` backend without `bucket_id` - so the service renders
# the whole config at run time, from a secret it sources itself, into a root-only
# runtime directory. A secret missing a line fails the unit by name instead of
# leaving an option unset for opendal to trip over later.
#
# The timer arms the RTC (WakeSystem) so a suspended laptop wakes at midnight,
# backs up, and is free to suspend again. A machine that is fully *off* at
# midnight cannot be woken from S5 by an RTC alarm on this hardware - Persistent
# catches that run up at the next boot instead.
#
# Three units, because "the backup succeeded" and "the backup is readable" are
# different claims: `rustic-backup` writes a snapshot, `rustic-check` reads a
# slice of the stored data back, and both announce their own failure.
#
# Starting over is deliberate and awkward, in that order. `--init` only creates a
# repository when its `config` object is absent, so a half-deleted prefix - what
# an interrupted run or a partial wipe leaves - fails with a credentials error
# until the prefix is emptied *completely*: stop both units, then
# `nix run nixpkgs#backblaze-b2 -- rm -r --versions b2://<bucket>/<root>/`, and
# the next run builds a fresh repository. `--versions` matters: without it B2
# keeps the old file versions and the storage stays billed.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  bucket = "megzari-strix-backups";
  root = "strix"; # subdir in the bucket, so other machines can share it later

  backupPaths = [ "/home" ];

  # rustic's `globs` are *include* patterns: a bare glob keeps what it matches and
  # drops the rest, so an exclusion has to be written with a leading `!`. Written
  # the other way round - as this list was until 19 Oct - every run backed up the
  # caches and build output and nothing else, silently, while reporting success.
  excludes = [
    "!**/.cache/**"
    "!**/.local/share/Trash/**"
    "!**/node_modules/**"
    "!**/target/**"
    "!**/.venv/**"
    "!**/__pycache__/**"
    "!**/.direnv/**"
  ];

  # The desktop user, for the failure notices below: a notification is only worth
  # sending if it lands on a session bus, and that bus belongs to whoever is
  # logged in. The rest of these units run as root.
  user = "yt";

  # The repository config cannot be built here: the three credential lines have to
  # sit inside [repository.options] and they only exist at run time, so the whole
  # file is rendered by the units' scripts, under a root-only $XDG_CONFIG_HOME that
  # each unit sets to its own runtime directory. This is that preamble, shared so
  # the backup and the check cannot drift into reading the repository differently;
  # it takes the local cache directory because rustic locks that directory, and two
  # units sharing one would fail each other rather than wait.
  configScript = cacheDir: ''
    set -euo pipefail

    # The agenix file is a shell-syntax list of assignments, so it is sourced
    # rather than parsed: systemd's EnvironmentFile silently drops a line it
    # cannot read, which is how a run with no bucket id reached opendal and
    # failed with "bucket_id is empty" thirteen milliseconds in. Nothing is
    # exported from here - the values are written into the config below - but
    # each one is required by name, so an empty or missing line fails with the
    # name of the line to fix.
    # shellcheck disable=SC1091
    . ${lib.escapeShellArg config.age.secrets.b2-credentials.path}

    : "''${RUSTIC_REPO_OPT_APPLICATION_KEY_ID:?b2-credentials: RUSTIC_REPO_OPT_APPLICATION_KEY_ID is unset or empty}"
    : "''${RUSTIC_REPO_OPT_APPLICATION_KEY:?b2-credentials: RUSTIC_REPO_OPT_APPLICATION_KEY is unset or empty}"
    : "''${RUSTIC_REPO_OPT_BUCKET_ID:?b2-credentials: RUSTIC_REPO_OPT_BUCKET_ID is unset or empty}"

    # A value written in quotes can carry padding, and padding is not part of
    # any credential - sent as part of the key it becomes an auth failure that
    # says nothing about the cause. Trim it and say when there was anything to
    # trim. An unquoted trailing space never reaches the variable at all, and a
    # CRLF-written file cannot be sourced, failing above with its line number.
    trim() {
      printf '%s' "$1" | sed 's/[[:space:]]*$//'
    }
    key_id=$(trim "$RUSTIC_REPO_OPT_APPLICATION_KEY_ID")
    key=$(trim "$RUSTIC_REPO_OPT_APPLICATION_KEY")
    bucket_id=$(trim "$RUSTIC_REPO_OPT_BUCKET_ID")

    trimmed=""
    [ "$key_id" = "$RUSTIC_REPO_OPT_APPLICATION_KEY_ID" ] || trimmed="$trimmed RUSTIC_REPO_OPT_APPLICATION_KEY_ID"
    [ "$key" = "$RUSTIC_REPO_OPT_APPLICATION_KEY" ] || trimmed="$trimmed RUSTIC_REPO_OPT_APPLICATION_KEY"
    [ "$bucket_id" = "$RUSTIC_REPO_OPT_BUCKET_ID" ] || trimmed="$trimmed RUSTIC_REPO_OPT_BUCKET_ID"
    [ -z "$trimmed" ] || echo "b2-credentials: trimmed trailing whitespace from$trimmed" >&2

    # What is left is written into a TOML basic string and sent to B2 as-is,
    # so only the shapes that cannot be a credential are refused; whether the
    # value is right is B2's answer, not this script's. Refusing on a charset
    # instead would turn a legitimate key into a failure of our own making.
    plain() {
      case "$2" in
        "") echo "b2-credentials: $1 is empty" >&2; exit 1 ;;
        *[[:space:]]*) echo "b2-credentials: $1 contains whitespace" >&2; exit 1 ;;
        *'"'* | *\\*) echo "b2-credentials: $1 contains a quote or a backslash" >&2; exit 1 ;;
        *[![:print:]]*) echo "b2-credentials: $1 contains a control character" >&2; exit 1 ;;
      esac
    }
    plain RUSTIC_REPO_OPT_APPLICATION_KEY_ID "$key_id"
    plain RUSTIC_REPO_OPT_APPLICATION_KEY "$key"
    plain RUSTIC_REPO_OPT_BUCKET_ID "$bucket_id"

    # Lengths only, no values: if these differ from what the file holds, the
    # file has padding or a stray character; if they match and B2 still
    # refuses, the problem is the credential itself, not how it is read.
    printf 'b2-credentials: key id %d chars, key %d chars, bucket id %d chars\n' \
      "''${#key_id}" "''${#key}" "''${#bucket_id}" >&2

    mkdir -p "$XDG_CONFIG_HOME/rustic"
    # 0600 from creation, so the key is never briefly more readable than that.
    install -m 0600 /dev/null "$XDG_CONFIG_HOME/rustic/rustic.toml"
    # The credential lines belong to [repository.options], which is why the
    # table is opened here rather than after everything else.
    cat > "$XDG_CONFIG_HOME/rustic/rustic.toml" <<CONFIG
    [repository]
    repository = "opendal:b2"
    password-file = "${config.age.secrets.rustic-password.path}"
    cache-dir = "${cacheDir}"

    [repository.options]
    bucket = "${bucket}"
    root = "${root}"
    bucket_id = "$bucket_id"
    application_key_id = "$key_id"
    application_key = "$key"

    [backup]
    globs = ${builtins.toJSON excludes}

    [forget]
    prune = true
    keep-daily = 14
    keep-weekly = 8
    keep-monthly = 6
    CONFIG
  '';

  # One of these per unit that can fail, wired to it with OnFailure. It runs as the
  # desktop user rather than root because it has to reach that user's session bus:
  # the journal is where a failure is recorded, but a notification is what someone
  # actually sees, and a backup that failed silently for three nights is exactly
  # the failure this is for.
  failureNotice = unit: {
    description = "announce that ${unit} failed";
    serviceConfig = {
      Type = "oneshot";
      User = user;
      Group = "users";
      # Nothing here may fail the notice itself: it is the last thing between a
      # broken backup and silence.
      ExecStart =
        let
          detail = "journalctl -u ${unit} -n 3 --no-pager -o cat 2>/dev/null | tr '\\n' ' ' | cut -c1-240";
        in
        pkgs.writeShellScript "rustic-failure-notice" ''
          export XDG_RUNTIME_DIR="/run/user/$(id -u)"
          export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
          detail=$(${detail} || true)
          ${pkgs.libnotify}/bin/notify-send -a rustic -u critical \
            ${lib.escapeShellArg "${unit} failed"} \
            "''${detail:-see: journalctl -u ${unit}}"
        '';
    };
  };
in
{
  age.secrets = {
    rustic-password.file = ../secrets/rustic.password.age;
    b2-credentials.file = ../secrets/b2.credentials.age;
  };

  systemd.tmpfiles.rules = [
    "d /var/cache/rustic 0755 root root -"
    # The check's own cache: rustic locks the directory it uses, so sharing one
    # would make the two units fail each other instead of waiting.
    "d /var/cache/rustic-check 0755 root root -"
  ];

  systemd.services.rustic-backup = {
    description = "Offsite backup to Backblaze B2";
    onFailure = [ "rustic-backup-failed.service" ];

    serviceConfig = {
      Type = "oneshot";
      # The rendered config holds the B2 application key, so it lives in a
      # root-only runtime directory systemd creates and removes with the unit:
      # not in the store, and not in the world-readable /etc.
      RuntimeDirectory = "rustic-backup";
      RuntimeDirectoryMode = "0700";
      # rustic reads <config-dir>/rustic/rustic.toml; the script writes it there.
      Environment = "XDG_CONFIG_HOME=/run/rustic-backup";
      # a backup must never compete with whatever is awake
      Nice = 19;
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
    };
    script = ''
      ${configScript "/var/cache/rustic"}

      # `--init` creates a repository only when its `config` object is absent. One
      # whose `config` survived but whose `keys/` object did not - what a partial
      # or interrupted deletion leaves - therefore fails every run with a
      # credentials error that names neither the cause nor the fix, so say it here.
      if ${pkgs.rustic}/bin/rustic backup --init ${lib.escapeShellArgs backupPaths}; then
        ${pkgs.rustic}/bin/rustic forget
      else
        echo "rustic-backup: the backup failed. If the error mentions credentials or a" >&2
        echo "missing keys/ object, the repository is partially deleted: empty the whole" >&2
        echo "b2://${bucket}/${root}/ prefix (stop this unit first) and run again - --init" >&2
        echo "only recreates a repository whose config object is absent." >&2
        exit 1
      fi
    '';
  };

  # The backup writing a snapshot says nothing about whether those packs can be
  # read back, and `forget` prunes the alternatives every night, so a corrupt pack
  # becomes the only copy before anything notices. `--read-data` with
  # `--read-data-subset` is what makes this a real check rather than a parse of the
  # index: it downloads a random slice of the stored packs. One percent of a
  # repository this size is minutes of work and a few GiB of B2 egress, and a
  # monthly run walks the whole repository in about eight years - which is slow on
  # purpose, since the metadata and index checks that catch most damage run in full
  # every time.
  systemd.services.rustic-check = {
    description = "Read a slice of the Backblaze B2 repository back";
    onFailure = [ "rustic-check-failed.service" ];

    serviceConfig = {
      Type = "oneshot";
      # Its own runtime directory, so the check never reads the config a backup
      # run is writing, or the other way round.
      RuntimeDirectory = "rustic-check";
      RuntimeDirectoryMode = "0700";
      Environment = "XDG_CONFIG_HOME=/run/rustic-check";
      # Reading a few GiB back must not compete with whatever is awake
      Nice = 19;
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
    };
    script = ''
      ${configScript "/var/cache/rustic-check"}

      ${pkgs.rustic}/bin/rustic check --read-data --read-data-subset 1%
    '';
  };

  systemd.services.rustic-backup-failed = failureNotice "rustic-backup";
  systemd.services.rustic-check-failed = failureNotice "rustic-check";

  systemd.timers.rustic-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00:00:00";
      Persistent = true;
      WakeSystem = true;
    };
  };

  systemd.timers.rustic-check = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # The 2nd, so the night's backup has landed and been pruned first; 04:00,
      # so a machine that woke at midnight for the backup is free to suspend
      # again. Persistent catches up a check the machine slept through.
      OnCalendar = "*-*-02 04:00:00";
      Persistent = true;
    };
  };
}
