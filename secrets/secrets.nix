let
  yt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGyQSeQ0CV/qhZPre37+Nd0E9eW+soGs+up6a/bwggoP";
  bee = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfjnEV/TFBBTdXTvkSGMyZeACljsb6HfXMuRUZro3QO";
  yt_at_bee = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN6izq2YuBOyFAhNmvyKtxH1vUlwiw0LbeopmmsodfDC yt@bee";
in
{
  "vaultwarden.env.age".publicKeys = [ yt bee ];
  "surreal.username.age".publicKeys = [ yt bee yt_at_bee ];
  "surreal.password.age".publicKeys = [ yt bee yt_at_bee ];
  "openai.key.age".publicKeys = [ yt bee yt_at_bee ];
  "github_access_token.age".publicKeys = [ yt yt_at_bee ];
  "canlii_api.key.age".publicKeys = [ yt bee ];
  "cloudflare.api.token.age".publicKeys = [ yt bee ];
  "sassy.technology.cloudflare.zone.id.age".publicKeys = [ yt bee ];
  "megzari.com.cloudflare.zone.id.age".publicKeys = [ yt bee ];
  "restic.backup.password.age".publicKeys = [ yt bee ];
  "restic.s3.credentials.age".publicKeys = [ yt bee ];
}
