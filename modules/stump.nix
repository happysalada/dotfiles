# Stump: comics/manga server for the family. Public at https://comic.megzari.com
# through the Cloudflare tunnel (modules/fundies-tunnel.nix), which dials
# 127.0.0.1, so no port is open to the internet or to the LANs this laptop
# joins. Clients: the web UI, or any OPDS reader.
#
# The unit sets ProtectHome, so keep the library out of /home.
{
  services.stump.enable = true;
}
