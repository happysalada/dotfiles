{
  enable = true;
  extraOptionOverrides = { Include = "~/.dotfiles/ssh.config"; };
  controlMaster = "auto";
  controlPath = "~/.ssh/control/%r@%h:%p";
  controlPersist = "5m";
  compression = true;
  matchBlocks = {
    "136.243.134.16" = {
      hostname = "136.243.134.16";
      identityFile = "~/.ssh/hetzner";
      user = "root";
    };
    "github.com" = {
      hostname = "github.com";
      identityFile = "~/.ssh/github_rsa";
    };
  };
  matchBlocks."*" = {
    extraOptions = {
      UseRoaming = "no";
      KexAlgorithms =
        "curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256";
      HostKeyAlgorithms =
        "ssh-ed25519-cert-v01@openssh.com,ssh-rsa-cert-v01@openssh.com,ssh-ed25519,ssh-rsa";
      Ciphers =
        "chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr";
      PubkeyAuthentication = "yes";
      MACs =
        "hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com";
      PasswordAuthentication = "no";
      ChallengeResponseAuthentication = "no";
      # UseKeychain = "yes";
      AddKeysToAgent = "yes";
      identityFile = "~/.ssh/id_rsa";
    };
  };
}
