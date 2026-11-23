# The Cloudflare R2 credentials for the fundies archive's blob store.
#
# The store asks the bucket for a blob by key, one key at a time, so the bucket and its
# endpoint are not secret and live in the fundies flake's `services.fundies.blobs`. What
# has to be on the machine is the key pair, under the standard AWS names, which systemd
# reads as root from this file (`environmentFile` in that same module).
#
# Create the secret before the first rebuild: `agenix -e r2.credentials.age` from
# secrets/, with two lines, AWS_ACCESS_KEY_ID=... and AWS_SECRET_ACCESS_KEY=...
{ pkgs, ... }:
{
  age.secrets.r2-credentials = {
    file = ../secrets/r2.credentials.age;
    owner = "yt";
    mode = "0400";
  };

  # For inspecting the bucket by hand; nothing in the system calls it.
  environment.systemPackages = [ pkgs.rclone ];
}
