let
  yt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGyQSeQ0CV/qhZPre37+Nd0E9eW+soGs+up6a/bwggoP";

  bee = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfjnEV/TFBBTdXTvkSGMyZeACljsb6HfXMuRUZro3QO";
in
{
  "vaultwarden.env.age".publicKeys = [ yt bee ];
  "erigon.jwt.age".publicKeys = [ yt bee ];
  "influxdb.token.age".publicKeys = [ yt bee];
}