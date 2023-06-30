{ config, pkgs, ... }:

let
  s3_url = "46d381004464b9e0c88b3bb5a0f0f100.r2.cloudflarestorage.com/backup";
  defaults = {
    initialize = true;
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
    passwordFile = config.age.secrets.BACKUP_PASSWORD.path;
    environmentFile = config.age.secrets.S3_CREDENTIALS.path;
    pruneOpts = [
      "--keep-daily 30"
      "--keep-weekly 52"
      "--keep-monthly 120"
    ];
  };
in
{
  services.restic = {
    backups = {
      postgresql = defaults // {
        paths = ["/root/pg_backup.sql"];
        repository = "s3:${s3_url}/postgresql";
        backupPrepareCommand = ''
          ${pkgs.sudo}/bin/sudo -u postgres ${pkgs.postgresql_15}/bin/pg_dumpall > /root/pg_backup.sql
        '';
      };
      # surrealdb = defaults // {
      #   paths = ["/root/backup.surql"];
      #   repository = "s3:${s3_url}/surrealdb";
      #   # TODO figure out how to inject the correct user and password.
      #   backupPrepareCommand = ''
      #     surreal backup http://127.0.0.1:${toString config.services.surrealdb.port}  /root/backup.surql --user ___ --pass ___ 
      #   '';
      # };
      bitwarden_rs = defaults // {
        paths = ["/var/lib/bitwarden_rs"];
        repository = "s3:${s3_url}/bitwarden_rs";
      };
      gitea = defaults // {
        paths = ["/var/lib/gitea"];
        repository = "s3:${s3_url}/gitea";
      };
      rustus = defaults // {
        paths = ["/var/lib/rustus"];
        repository = "s3:${s3_url}/rustus";
      };
    };
  };

  age.secrets =  {
    BACKUP_PASSWORD = {
      file = ../secrets/restic.backup.password.age;
    };
    S3_CREDENTIALS = {
      file = ../secrets/restic.s3.credentials.age;
    };
  };
}
