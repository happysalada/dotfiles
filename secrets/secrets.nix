# agenix access-control list: maps each encrypted file under secrets/ to the
# public keys allowed to decrypt it.
#
# Emptied 2026-08-22: every previous secret was stale and got deleted along
# with its .age file. The recipient lists that used to live here are in git
# history if you want them back.
#
# NOTE: deleting the .age files did NOT revoke anything. The old ciphertext is
# still in git history and still decryptable by any of the keys below, so the
# credentials themselves have to be rotated at each provider (Cloudflare,
# OpenAI/Anthropic, R2/S3, restic, Vaultwarden, SurrealDB, ...).
#
# To add a secret back:
#   1. add an entry here, e.g.  "openai.key.age".publicKeys = [ yt_at_strix ];
#   2. agenix -e secrets/openai.key.age
#   3. declare it in the consuming module as age.secrets.<NAME>.file
#
# After changing any recipient list, run `agenix -r` from a machine that
# already holds one of the existing keys.
let
  yt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGyQSeQ0CV/qhZPre37+Nd0E9eW+soGs+up6a/bwggoP";
  bee = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfjnEV/TFBBTdXTvkSGMyZeACljsb6HfXMuRUZro3QO";
  yt_at_bee = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN6izq2YuBOyFAhNmvyKtxH1vUlwiw0LbeopmmsodfDC yt@bee";
  yt_at_strix = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEkeMf/jAULrCSbdXHIE8SqSB3CFgDDsIgJz9OmDb6fy yt@strix";
  hetz = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIByQBosyis0iJG5F4Dt72DOR9xtlL4wM/q1lbMA6cu+F root@hetzner-AX41-UEFI-ZFS-NVME";
in
# The key definitions above are deliberately kept despite being unused right
# now, so recreating a secret is a one-line change rather than a copy-paste
# from another machine.
{
}
