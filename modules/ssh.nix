{ ... }:

{
  # agent can only be started as non root
  # This seems to cause problems
  # programs.ssh.startAgent = true;

  services = {
    openssh = {
      enable = true;
      settings.PermitRootLogin = "prohibit-password";
      settings.KbdInteractiveAuthentication = false;
      settings.PasswordAuthentication = false;
      listenAddresses = [
        {
          addr = "0.0.0.0";
          port = 22;
        }
        {
          addr = "[::]";
          port = 22;
        }
      ];
    };
  };
}
