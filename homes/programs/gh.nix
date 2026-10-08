# The GitHub CLI, as configuration and as a credential.
#
# Three things live here, which is why this is a home-manager module rather than
# one more `programs.gh = ...` fragment in machines/strix:
#
#   1. config.yml, which `programs.gh` now owns. What used to live in that file
#      imperatively is declared here; on the first rebuild the existing file is
#      moved aside as config.yml.hm-bak (home-manager.backupFileExtension). Keys
#      home-manager does not write - pager, editor, prompt, spinner, the three
#      accessible_* toggles, telemetry - drop out of the file and come back from
#      gh's own defaults, which is what they held anyway; `gh config list` still
#      reports them.
#
#   2. hosts.yml, which is deliberately NOT declared. `programs.gh.hosts` links
#      that file out of the store, and gh writes it itself: `gh auth login`,
#      `gh auth refresh`, `gh auth switch` and `gh auth logout` all rewrite it,
#      and it holds the token when the token is not in the keyring. A read-only
#      symlink there would break login instead of making it reproducible. The
#      account stays machine state - `gh auth status --json hosts` is how to
#      read it back (login, state, tokenSource, scopes).
#
#   3. The token itself, from secrets/github.token.age. gh has no "token file"
#      option, so a stored credential can only arrive through the environment:
#      the secret is decrypted to ~/.config/gh/token and nushell's env file
#      exports it as GH_TOKEN, which takes precedence over the keyring.
{ config, ... }:
let
  # Absolute, concrete path rather than agenix's ${XDG_RUNTIME_DIR} default:
  # the env file below interpolates it into nushell source, where a literal
  # `${...}` would never expand.
  tokenPath = "${config.xdg.configHome}/gh/token";
in
{
  programs.gh = {
    enable = true;

    settings = {
      # Recorded per host by `gh auth login`; the file-level default is https and
      # the two disagreed (hosts.yml said ssh, config.yml said https). ssh is
      # what this machine actually uses - homes/programs/git.nix rewrites
      # https://github.com/happysalada to git@github.com:happysalada, and
      # `gh auth status` reports "Git operations protocol: ssh".
      git_protocol = "ssh";

      aliases = {
        co = "pr checkout";
      };
    };

    # Off, unlike home-manager's 26.x default. On, it puts gh's helper on
    # `credential."https://github.com".helper`, whose leading empty value resets
    # the helper list for that host - so git would reach for this token over
    # https and stop using git.nix's libsecret helper there. github remotes are
    # rewritten to ssh on this machine, so the helper would only ever change
    # behaviour in the one case it is least wanted.
    gitCredentialHelper.enable = false;
  };

  # Mode 0400, owned by the user, next to the config it belongs to - the same
  # shape .reasonix/.env has for the DeepSeek key.
  age.secrets.github-token = {
    file = ../../secrets/github.token.age;
    path = tokenPath;
  };

  # GH_TOKEN wins over the keyring, so every gh call from a nushell shell - and
  # every process that shell starts, agents included - uses the PAT instead of
  # the `gh auth login` entry. Reading it defensively is deliberate: the file is
  # absent until the first activation, and while the ciphertext is still empty
  # the variable has to stay *unset* rather than become "" or a stale value, so
  # that gh falls back to the keyring exactly as it did before.
  programs.nushell.extraEnv = ''
    let ghToken = (try { open "${tokenPath}" | str trim } catch { "" })
    if ($ghToken | is-not-empty) { $env.GH_TOKEN = $ghToken }
  '';
}
