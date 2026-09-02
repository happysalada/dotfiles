# NetBird: puts strix on a private WireGuard mesh so the phone can reach it
# from anywhere, without opening a single port to the internet.
#
# Control plane is NetBird's hosted one (app.netbird.io, free tier). That is
# the binary's built-in default, so there is no management URL to set here -
# only `netbird up` once, interactively, to bind this peer to the account.
# Traffic between peers is direct WireGuard; the cloud side only brokers
# keys and NAT traversal.
#
# What this file opens, and only on the mesh interface:
#   - 22           sshd, which strix otherwise does not run at all
#   - 4096         the opencode server (homes/programs/opencode-server.nix)
#   - 60000-61000  mosh, one UDP port per live session
#
# Neither is reachable from wifi, LAN, or anywhere else - `nb0` is named
# explicitly below precisely so the firewall can be scoped to it.
{ config, ... }:
let
  # homes/programs/opencode-server.nix serves on this; kept in sync by hand
  # rather than through a shared module, since the two live on opposite sides
  # of the system/home-manager split.
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

  # Naming the client `netbird` (rather than, say, `default`) keeps the CLI as
  # plain `netbird` and the unit as `netbird.service`; any other name suffixes
  # both.
  users.users.yt.extraGroups = [ "netbird" ];

  # NetBird serves `*.netbird.cloud` itself, so it has to install a resolver.
  # NetworkManager's default mode owns /etc/resolv.conf outright and the two
  # then fight over it; handing DNS to resolved gives NetBird a per-domain
  # route to register instead. The netbird module already ships the polkit
  # rule that lets its daemon talk to resolved, but only when resolved is on.
  services.resolved.enable = true;
  networking.networkmanager.dns = "systemd-resolved";

  # ---------------------------------------------------------------------
  # sshd
  #
  # NOT modules/ssh.nix - that one listens on 0.0.0.0 for a server sitting in
  # a datacentre. On a laptop that would offer port 22 to every coffee-shop
  # network it joins. `openFirewall = false` plus the interface-scoped rule
  # below means the only way in is across the mesh.
  # ---------------------------------------------------------------------
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # ---------------------------------------------------------------------
  # mosh
  #
  # Not a replacement for sshd. `mosh` is a wrapper that logs in over
  # OpenSSH, starts mosh-server at the far end, learns its UDP port and
  # only then takes over - so the sshd above stays load-bearing.
  #
  # What it buys is the part plain SSH cannot do over a phone: the session
  # survives wifi -> cellular, survives the handset sleeping, and echoes
  # locally so typing stays responsive on a laggy link. Zellij keeps the
  # session; mosh keeps the connection to it.
  #
  # `openFirewall = false` is the load-bearing line. The module's own
  # version writes `networking.firewall.allowedUDPPortRanges`, which is
  # global - it would put 1000 UDP ports on every network this laptop
  # joins, undoing the whole point of the interface scoping below.
  #
  # NOT netbird's built-in SSH server (`netbird up --allow-server-ssh`),
  # which looked like it would delete all the key management here. It only
  # accepts OpenSSH clients carrying netbird's own ssh_config drop-in and a
  # local netbird daemon to mint the JWT, so a phone SSH client cannot
  # speak to it - and it re-routes :22 to its own :22022, colliding with
  # the sshd above.
  # ---------------------------------------------------------------------
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

  # opencode-server is a *user* unit, and user units only run while that user
  # has a session. Without lingering it would be up only when someone is
  # logged in at the laptop - i.e. exactly not the case when reaching for the
  # phone. Lingering starts yt's user manager at boot instead.
  #
  # `manageLingering` is required for `linger` to be settable at all
  # (users-groups.nix asserts on it). It only touches users that state a
  # value, so the other accounts are left alone.
  users.manageLingering = true;
  users.users.yt.linger = true;
}
