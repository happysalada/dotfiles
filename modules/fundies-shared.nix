# yt and fundies share /var/lib/fundies: the services own the data and the
# operator's account can write what they create and vice versa.
#
# The access is granted to the operator's *uid* as well as to the group, because a
# supplementary group is fixed when a session starts - and the user manager here
# starts at boot and lingers past logout, so a group added now would not reach the
# running session, or pueued and the jobs it spawns, until a reboot. An ACL entry
# naming the account works immediately and needs nothing restarted.
#
# Setgid still matters: it keeps new objects in the data's own group, so the group
# route is there for a login that does pick the membership up. The default ACL is
# the part chmod cannot express - it keeps new files writable by both accounts
# whatever umask the writer had, which 022 for a service or a shell would otherwise
# reduce to 0644. Nothing becomes world accessible.
#
# The mode is re-applied on every activation rather than once: the fundies module
# creates these same directories with `d ... 0750`, and activation also resets the
# account's home - which is this directory - from homeMode. Later lines win, hence
# `mkAfter` and the `z` lines beside each `d`.
{ config, lib, ... }:
let
  user = config.services.fundies.user;
  group = config.services.fundies.group;
  dataDir = config.services.fundies.dataDir;
  operator = "yt";

  # The mask is explicit: acl_from_text, which tmpfiles and setfacl both use, wants
  # one as soon as there is a named entry.
  acl = "u::rwx,u:${operator}:rwx,g::rwx,m::rwx,o::---,d:u::rwx,d:u:${operator}:rwx,d:g::rwx,d:m::rwx,d:o::---";

  # The directories the fundies module creates, plus anything this repository adds.
  # A directory the services create later inherits both the setgid bit and the
  # default ACL from its parent, so it needs no line here; one the *module* creates
  # needs both, because its `d ... 0750` runs first.
  dirs = map (suffix: if suffix == "" then dataDir else "${dataDir}/${suffix}") [
    ""
    "company"
    "prices"
    "prices/tmp"
    "search"
    "releases"
    "releases/mops"
    "releases/edinet"
    "identity"
    "gleif"
    "store"
  ];

  rules = lib.concatMap (dir: [
    "d ${dir} 2770 ${user} ${group} -"
    "z ${dir} 2770 ${user} ${group} -"
    "a+ ${dir} - - - - ${acl}"
  ]) dirs;
in
{
  # Kept for a login that does pick the group up; nothing here depends on it, so a
  # running session needs no refresh before the jobs can write.
  users.users.${operator}.extraGroups = [ group ];

  # The fundies module gives this account dataDir as its home with createHome, and
  # activation rewrites the home directory's mode from homeMode, which defaults to
  # 0700.
  users.users.${user}.homeMode = "2770";

  systemd.tmpfiles.rules = lib.mkAfter rules;
}
