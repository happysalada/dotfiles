{ pkgs }:
{
  enable = true;
  enableNushellIntegration = true;

  settings = {
    # NOTE: this table was called `manager` until yazi 25.5; it's `mgr` now and
    # the old name is silently ignored.
    mgr = {
      show_hidden = true;
      show_symlink = true;
      sort_dir_first = true;
      sort_by = "size";
      sort_reverse = true;
      linemode = "size";
    };
  };
}
