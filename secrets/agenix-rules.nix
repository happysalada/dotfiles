# agenix access-control list: maps each encrypted file under secrets/ to the
# public keys allowed to decrypt it.
#
# Reset 2026-08-22: every previous secret was stale and got deleted along with
# its .age file. The old recipient lists remain in git history.
#
# NOTE: deleting the .age files did NOT revoke anything. The old ciphertext is
# still in git history and still decryptable by any of the keys below, so the
# credentials themselves have to be rotated at each provider (Cloudflare,
# OpenAI/Anthropic, R2/S3, restic, Vaultwarden, SurrealDB, ...).
#
# To add a secret back:
#   1. add an entry here, e.g.  "openai.key.age".publicKeys = [ yt_at_strix ];
#   2. agenix -e openai.key.age
#   3. declare it in the consuming module as age.secrets.<NAME>.file
#
# Run agenix from this directory so it discovers agenix-rules.nix. After
# changing any recipient list, run `agenix -r` from a machine that already
# holds one of the existing keys.
let
  yt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGyQSeQ0CV/qhZPre37+Nd0E9eW+soGs+up6a/bwggoP";
  bee = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfjnEV/TFBBTdXTvkSGMyZeACljsb6HfXMuRUZro3QO";
  yt_at_bee = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN6izq2YuBOyFAhNmvyKtxH1vUlwiw0LbeopmmsodfDC yt@bee";
  yt_at_strix = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEkeMf/jAULrCSbdXHIE8SqSB3CFgDDsIgJz9OmDb6fy yt@strix";
  hetz = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIByQBosyis0iJG5F4Dt72DOR9xtlL4wM/q1lbMA6cu+F root@hetzner-AX41-UEFI-ZFS-NVME";
in
# Unused keys stay here so adding a recipient remains a one-line change.
{
  "deepseek.api.key.age".publicKeys = [ yt_at_strix ];

  # A fine-grained, read-only GitHub PAT, read as `$env.GH_TOKEN` by the agent
  # entry points at launch (declared in homes/programs/gh.nix, read by nono.nix
  # and machines/strix/reasonix.nu). strix only for now: it is the machine with a
  # keyring login to fall back on, and bee/hetz read nothing from it yet - this
  # list grows only when a server needs the token itself. The ciphertext is
  # created with an empty plaintext and stays empty until a token is pasted in;
  # gh reads an empty GH_TOKEN as unset and keeps using the keyring login.
  "github.token.age".publicKeys = [ yt_at_strix ];

  # rustic offsite backups: the repository password (the encryption key for the
  # whole repo - losing it loses the backups) and the B2 application key, which
  # also carries the bucket id. strix only for now.
  "rustic.password.age".publicKeys = [ yt_at_strix ];
  "b2.credentials.age".publicKeys = [ yt_at_strix ];

  # Repository password of the local restic backup on the second drive
  # (modules/restic-local.nix). Same warning as rustic's: losing it loses the
  # backups, so keep a copy outside this machine.
  "rustic-local.password.age".publicKeys = [ yt_at_strix ];

  # Meilisearch master key (modules/meilisearch.nix). strix only for now, same
  # as the two above - grow the list when bee's instance is revived.
  "meilisearch.master-key.age".publicKeys = [ yt_at_strix ];

  # fundies API keys, read as systemd credentials by services.fundies. strix
  # only: the pipelines run there. Empty until a key is pasted with
  # `agenix -e <file>` from secrets/.
  "edinet.api.key.age".publicKeys = [ yt_at_strix ];
  "dart.api.key.age".publicKeys = [ yt_at_strix ];
  "openpermid.api.key.age".publicKeys = [ yt_at_strix ];
  "openfigi.api.key.age".publicKeys = [ yt_at_strix ];

  # URLHaus Auth-Key from auth.abuse.ch. Every URLHaus export now sits behind
  # one, on urlhaus-api.abuse.ch, so a fetcher for its ClamAV signature file
  # would read this. fangfrisch cannot: it sends no auth header and still
  # points at the retired /downloads/ path. strix only for now.
  "urlhaus.api.key.age".publicKeys = [ yt_at_strix ];

  # The credentials JSON from `cloudflared tunnel create fundies`, read by
  # services.cloudflared in modules/fundies-tunnel.nix. It carries the tunnel
  # secret, not an API token, so it belongs to this machine's agenix identity.
  "cloudflare-tunnel-fundies.age".publicKeys = [ yt_at_strix ];
}
