# The Cloudflare R2 bucket that holds the fundies archive blobs.
#
# One agenix file carries the S3 credentials under the standard AWS names, so rclone,
# opendal, rustic and the aws cli all read the same secret. The endpoint and bucket are
# not secret and live here.
#
# Create the secret before the first rebuild: `agenix -e r2.credentials.age` from
# secrets/, with two lines, AWS_ACCESS_KEY_ID=... and AWS_SECRET_ACCESS_KEY=...
{ config, lib, pkgs, ... }:
let
  endpoint = "https://46d381004464b9e0c88b3bb5a0f0f100.r2.cloudflarestorage.com";
  bucket = "fundies-store";
  blobs = "${config.services.fundies.storeDir}/blobs";
  secret = "r2-credentials";

  # `rclone copy` skips a key that exists: blobs are named by their digest.
  upload = pkgs.writeScriptBin "fundies-r2-upload" ''
    #!${pkgs.nushell}/bin/nu
    # Copy the local blobs into the bucket. A dry run unless --apply.
    def main [
      --apply # upload for real
      --transfers: int = 32
      --bwlimit: string = "0" # e.g. 50M
    ] {
      let flags = ["--ignore-existing" "--transfers" $transfers "--checkers" 64 "--bwlimit" $bwlimit "--stats" "1m" "--stats-one-line"]
      let flags = if $apply { $flags } else { $flags | append "--dry-run" }
      with-env (r2-env) { ^rclone copy ${blobs} ":s3:${bucket}/blobs" ...$flags }
    }

    # Whether every local blob is in the bucket with the same size.
    def "main check" [] {
      with-env (r2-env) {
        ^rclone check ${blobs} ":s3:${bucket}/blobs" --size-only --one-way --checkers 64 --stats 1m --stats-one-line
      }
    }

    def r2-env [] {
      open --raw ${config.age.secrets.${secret}.path}
      | lines | where {|line| $line != "" } | parse "{name}={value}" | transpose --header-row --as-record
      | merge {
        RCLONE_S3_PROVIDER: Cloudflare
        RCLONE_S3_ENV_AUTH: "true"
        RCLONE_S3_ENDPOINT: "${endpoint}"
        RCLONE_S3_NO_CHECK_BUCKET: "true"
      }
    }
  '';
in
{
  age.secrets.${secret} = {
    file = ../secrets/r2.credentials.age;
    owner = "yt";
    mode = "0400";
  };

  environment.systemPackages = [
    pkgs.rclone
    upload
  ];
}
