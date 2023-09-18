let
  yt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGyQSeQ0CV/qhZPre37+Nd0E9eW+soGs+up6a/bwggoP";
  bee = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfjnEV/TFBBTdXTvkSGMyZeACljsb6HfXMuRUZro3QO";
  yt_at_bee = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN6izq2YuBOyFAhNmvyKtxH1vUlwiw0LbeopmmsodfDC yt@bee";
  hetz = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIByQBosyis0iJG5F4Dt72DOR9xtlL4wM/q1lbMA6cu+F root@hetzner-AX41-UEFI-ZFS-NVME";
in
{
  "vaultwarden.env.age".publicKeys = [ yt bee ];
  "surreal.username.age".publicKeys = [ yt bee yt_at_bee hetz ];
  "surreal.password.age".publicKeys = [ yt bee yt_at_bee hetz ];
  "openai.key.age".publicKeys = [ yt bee yt_at_bee ];
  "github_access_token.age".publicKeys = [ yt yt_at_bee ];
  "canlii_api.key.age".publicKeys = [ yt bee ];
  "cloudflare.api.token.age".publicKeys = [ yt bee ];
  "sassy.technology.cloudflare.zone.id.age".publicKeys = [ yt bee ];
  "megzari.com.cloudflare.zone.id.age".publicKeys = [ yt bee ];
  "restic.backup.password.age".publicKeys = [ yt bee hetz ];
  "restic.s3.credentials.age".publicKeys = [ yt bee hetz ];
  "rustus.r2.access.key.age".publicKeys = [ yt bee hetz ];
  "rustus.r2.secret.key.age".publicKeys = [ yt bee hetz ];
  "huggingface.token.age".publicKeys = [ yt bee ];
  "unstructured.api.key.age".publicKeys = [ yt bee ];
}
