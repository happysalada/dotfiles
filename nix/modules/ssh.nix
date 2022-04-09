{ config, lib, pkgs, ... }:

{
  # agent can only be started as non root
  programs.ssh.startAgent = true;

  services = {
    openssh = {
      enable = true;
      permitRootLogin = "prohibit-password";
      passwordAuthentication = false;
      kbdInteractiveAuthentication = false;
    };
  };
}
