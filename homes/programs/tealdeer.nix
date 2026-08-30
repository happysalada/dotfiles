{ ... }:
{
  enable = true;

  # The binary also comes from packages/basic_cli_set.nix, which the machines
  # without a home-manager profile still need. Same derivation, so the overlap
  # costs nothing; this module is here for the config and the timer.
  #
  # Unrelated to intelli-shell's ctrl-space, which keeps its own copy of the
  # tldr pages in its store (`intelli-shell tldr fetch`). This is only for
  # `tldr <cmd>` typed directly.
  settings.updates = {
    # tealdeer ships no page cache, and a missing cache is indistinguishable
    # from a missing page - the lookup just comes back empty. Refresh on first
    # use after a week rather than making that a manual chore.
    auto_update = true;
    auto_update_interval_hours = 168;
  };
}
