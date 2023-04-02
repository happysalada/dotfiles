let
  yt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGyQSeQ0CV/qhZPre37+Nd0E9eW+soGs+up6a/bwggoP";

  bee = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfjnEV/TFBBTdXTvkSGMyZeACljsb6HfXMuRUZro3QO";
in
{
  "vaultwarden.env.age".publicKeys = [ yt bee ];
  "erigon.jwt.age".publicKeys = [ yt bee ];
  "influxdb.token.age".publicKeys = [ yt bee ];
  "surreal.username.age".publicKeys = [ yt bee ];
  "surreal.password.age".publicKeys = [ yt bee ];
  "gcloud_secrets.env.age".publicKeys = [ yt bee ];
  "openai.key.age".publicKeys = [ yt bee ];
  "twitter.bearer_token.age".publicKeys = [ yt bee ];
  "chatgpt_retrieval_plugin.bearer_token.age".publicKeys = [ yt bee ];
  "env.nu.age".publicKeys = [ yt ];
}
