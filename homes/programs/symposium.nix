# Symposium's user config, declared rather than produced by `cargo agents init`.
#
# init writes this same file, but it also registers hooks, and at its default
# `hook-scope = "global"` that means merging entries into ~/.claude/settings.json
# - a mode-444 store symlink here, so the write fails outright. Pinning the
# scope to "project" keeps it out of the home directory entirely.
#
# The cost of that choice: hooks are per-project, so a new checkout needs one
# `cargo agents sync` before Symposium activates in it. After that `auto-sync`
# keeps the installed skills current on its own.
{ ... }:
{
  home.file.".symposium/config.toml".text = ''
    # Generated from homes/programs/symposium.nix - do not edit in place.
    # This is a read-only store symlink; `cargo agents init` and
    # `cargo agents use` cannot write to it. Edit the nix file and rebuild.

    # Re-scan dependencies on each hook invocation and refresh installed skills.
    auto-sync = true

    # Mirror skills authored in a workspace's .agents/skills/ into .claude/skills/,
    # since Claude Code does not read the vendor-neutral path.
    agents-syncing = true

    # Hooks go in the project, never in ~/.claude/settings.json. See above.
    hook-scope = "project"

    # "on" would `cargo install` a newer release over itself and re-exec. Against
    # a read-only store path that is either a failure or a silent divergence from
    # what nix installed, so updates come from bumping packages/ai/symposium.nix.
    auto-update = "off"

    [[agent]]
    name = "claude"

    [[agent]]
    name = "opencode"

    [logging]
    level = "info"

    # Off by default upstream too; stated so the choice is recorded rather than
    # inherited. Nothing is uploaded even when enabled, but nothing needs to be.
    [telemetry]
    enabled = false

    [defaults]
    # The plugin list curated by the Symposium project.
    symposium-recommendations = true
    # ~/.symposium/plugins/, for plugins written here.
    user-plugins = true

    # Consent for plugins embedded in dependencies. Deliberately empty: a crate
    # you depend on is not automatically allowed to add instructions to an agent,
    # and `auto-enable = ["*"]` would hand that power to every crate in the tree.
    #
    # 0.4.0 parses this table but does not act on it yet - the gating is
    # documented ahead of the release. Stated now so the default is explicit
    # rather than inherited the day a version bump starts honouring it.
    [plugins]
    auto-enable = [ ]
    use = [ ]
    disable = [ ]
  '';
}
