{
  enable = true;
  controlMaster = "auto";
  controlPath = "~/.ssh/control/%r@%h:%p";
  controlPersist = "5m";
  compression = true;
  matchBlocks = {
    "bee" = {
      # hostname = "174.94.78.215";
      hostname = "70.29.213.241";
      user = "yt";
    };
    "hetz" = {
      hostname = "116.202.222.51";
      user = "yt";
    };
  };
  matchBlocks."*" = {
    extraOptions = {
      Protocol = "2";

      # also this stuff
      TCPKeepAlive = "yes";
      ServerAliveInterval = "20";
      ServerAliveCountMax = "10";

      # stop bugging me about a new host
      StrictHostKeyChecking = "no";

      # run gui programs on local
      ForwardX11 = "yes";
      UseRoaming = "no";
      KexAlgorithms = "curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256";
      HostKeyAlgorithms = "ssh-ed25519-cert-v01@openssh.com,ssh-rsa-cert-v01@openssh.com,ssh-ed25519,ssh-rsa";
      Ciphers = "chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr";
      PubkeyAuthentication = "yes";
      MACs = "hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com";
      PasswordAuthentication = "no";
      ChallengeResponseAuthentication = "no";
      # UseKeychain = "yes";
      AddKeysToAgent = "yes";
      identityFile = "~/.ssh/id_ed25519";
      ForwardAgent = "yes"; # enables use of local ssh agent (e.g. for github)
    };
  };
}
