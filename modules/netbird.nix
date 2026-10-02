# NetBird: puts strix on a private WireGuard mesh so the phone can reach it
# from anywhere without opening a port to the internet. Control plane is
# NetBird's hosted one (app.netbird.io, free tier) - the binary's built-in
# default, so only `netbird up` once, interactively, binds this peer. Opens,
# on the mesh interface only (`nb0`, named below so the firewall scopes to it):
#   - 22           sshd, which strix otherwise does not run at all
#   - 4096         the opencode server (homes/programs/opencode-server.nix)
#   - 60000-61000  mosh, one UDP port per live session
{ config, ... }:
let
  # homes/programs/opencode-server.nix serves on this; kept in sync by hand
  # because the two live on opposite sides of the system/home-manager split.
  opencodePort = 4096;
in
{
  services.netbird.clients.netbird = {
    port = 51820;

    # Default would be `nb-netbird`. Short and fixed so the firewall stanza
    # below can name it, and so `strix.netbird.cloud` resolves predictably.
    interface = "nb0";

    # `hardened` (the default) runs the daemon as its own user rather than
    # root, and gates the control socket behind the `netbird` group - which is
    # why yt joins it below. Without that, every `netbird status` needs sudo.
  };

  # Naming the client `netbird` keeps the CLI as plain `netbird` and the unit
  # as `netbird.service`; any other name suffixes both.
  users.users.yt.extraGroups = [ "netbird" ];

  # NetBird serves `*.netbird.cloud` itself, so it must install a resolver;
  # NetworkManager's default mode owns /etc/resolv.conf and the two would fight
  # over it. Handing DNS to resolved gives NetBird a per-domain route to
  # register - and the module's polkit rule only loads when resolved is on.
  services.resolved.enable = true;
  networking.networkmanager.dns = "systemd-resolved";

  # sshd. NOT modules/ssh.nix - that listens on 0.0.0.0 for a datacentre
  # server, so on a laptop it would offer port 22 to every network it joins.
  # `openFirewall = false` plus the interface-scoped rule below means the only
  # way in is across the mesh.
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # mosh. Not a replacement for sshd: it logs in over OpenSSH, starts
  # mosh-server at the far end, learns its UDP port and only then takes over -
  # so the sshd above stays load-bearing. It buys what plain SSH cannot over a
  # phone: the session survives wifi -> cellular and the handset sleeping, with
  # local echo on a laggy link (Zellij keeps the session; mosh the connection).
  #
  # `openFirewall = false` is load-bearing - the module's own version writes a
  # global `allowedUDPPortRanges`, putting 1000 UDP ports on every network this
  # laptop joins and undoing the interface scoping below.
  #
  # NOT netbird's built-in SSH server (`netbird up --allow-server-ssh`): it
  # only accepts clients carrying netbird's ssh_config drop-in and a local
  # netbird daemon to mint the JWT, so a phone client cannot speak to it - and
  # it re-routes :22 to :22022, colliding with the sshd above.
  programs.mosh = {
    enable = true;
    openFirewall = false;
  };

  networking.firewall.interfaces.${config.services.netbird.clients.netbird.interface} = {
    allowedTCPPorts = [
      22
      opencodePort
    ];
    # mosh's default range; it claims one port per concurrent session
    allowedUDPPortRanges = [
      {
        from = 60000;
        to = 61000;
      }
    ];
  };

  # opencode-server is a *user* unit, and user units run only while the user
  # has a session - i.e. not when reaching for the phone. Lingering starts yt's
  # user manager at boot instead.
  #
  # `manageLingering` is required for `linger` to be settable at all
  # (users-groups.nix asserts on it); it only touches users that state a value.
  users.manageLingering = true;
  users.users.yt.linger = true;
}
