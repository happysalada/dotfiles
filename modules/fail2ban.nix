{ pkgs, ...}:
{
  # ssh-iptables jail is enabled by default
  services.fail2ban = {
    enable = true;
    ignoreIP = [
      "192.168.2.0/24"
    ];
    bantime-increment = {
      enable = true;

      maxtime = "48h";
      factor = "600";
    };

    extraPackages = [ pkgs.ipset ];
    banaction = "iptables-ipset-proto6-allports";
    # if ever needed, can find some stuff at https://git.hubrecht.ovh/hubrecht/nixos/src/branch/master/modules/ht-fail2ban/jails.nix
  };
}