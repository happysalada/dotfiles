{ lib }:
{
  enable = true;
  # home-manager's built-in defaults are on their way out; everything we care
  # about is set explicitly in settings."*" below.
  enableDefaultConfig = false;

  settings = {
    bee = {
      # HostName = "174.94.78.215";
      HostName = "69.157.23.176";
      User = "yt";
    };

    hetz = {
      HostName = "116.202.222.51";
      User = "yt";
    };

    # ssh takes the *first* value it sees for each option, so the catch-all has
    # to be emitted after the specific hosts
    "*" = lib.hm.dag.entryAfter [ "bee" "hetz" ] {
      Compression = true;

      ControlMaster = "auto";
      # %C is a hash of (local host, remote host, port, user) - keeps the socket
      # path well under the 108-char unix socket limit that %r@%h:%p can blow
      ControlPath = "~/.ssh/control/%C";
      ControlPersist = "5m";

      TCPKeepAlive = "yes";
      ServerAliveInterval = 20;
      ServerAliveCountMax = 10;

      # `no` disabled host-key checking entirely, which also silently accepts a
      # CHANGED key for a known host - i.e. no MITM protection at all.
      # `accept-new` still auto-trusts first contact, but refuses if a known
      # host's key ever changes.
      StrictHostKeyChecking = "accept-new";
      HashKnownHosts = true;

      # run gui programs on local
      ForwardX11 = "yes";

      # Ciphers/MACs/KexAlgorithms/HostKeyAlgorithms are deliberately NOT set.
      # The hand-rolled lists that used to live here still permitted ssh-rsa
      # (SHA-1) and diffie-hellman-group-exchange-sha256; OpenSSH's own
      # defaults are stricter than that and get tightened upstream over time.

      PubkeyAuthentication = "yes";
      PasswordAuthentication = "no";
      AddKeysToAgent = "yes";
      IdentityFile = "~/.ssh/id_ed25519";
      ForwardAgent = true; # enables use of local ssh agent (e.g. for github)
    };
  };
}
