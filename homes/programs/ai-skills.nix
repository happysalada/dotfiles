# Agent skills, shared by claude-code and opencode.
#
# Both modules take the same `name -> store path` shape, so one attrset feeds
# both - the same split ai-context.nix and ai-mcp.nix already use for
# instructions and MCP servers.
#
# Cherry-picked, never whole repos. Claude Code loads every installed skill's
# description into a listing budgeted at 1% of the context window, and once that
# overflows it drops descriptions starting with the skills invoked least. Pulling
# all 165 scientific skills would make the eleven below harder to match, not
# easier - and it would cost 248MB of closure instead of 3.5MB.
{ pkgs }:
let
  # The domain-neutral quantitative core of a repo that is otherwise
  # bioinformatics. Deliberately none of the genomics or cheminformatics.
  quantitative = [
    "exploratory-data-analysis"
    "matplotlib"
    "polars"
    "pymc" # Bayesian inference, hierarchical models
    "pymoo" # multi-objective optimisation
    "scikit-learn"
    "shap" # attribution - why the model said that
    "statistical-analysis" # test selection, effect sizes, reporting
    "statistical-power" # sample size before the backtest, not after
    "statsmodels" # OLS/GLM/ARIMA, econometric diagnostics
    "timesfm-forecasting"
  ];

  # Method, not domain. Five of superpowers' fourteen, taken as-is.
  #
  # Left out: using-git-worktrees and finishing-a-development-branch drive the
  # agent to stage and commit, which the Git section of ai-context.nix forbids
  # outright, and to make worktrees, which it allows only when asked.
  # executing-plans goes with them - it carries a "REQUIRED SUB-SKILL"
  # pointer into that pair, so taking it would smuggle the commit workflow back
  # in through a dangling reference. The five below reference only each other.
  #
  # writing-plans had the same problem and is vendored instead, see below.
  methodology = [
    "brainstorming"
    "receiving-code-review"
    "systematic-debugging"
    "test-driven-development"
    "verification-before-completion"
  ];

  # Pinned by tag, so an upgrade is a reviewable diff rather than a moving
  # dependency - and so third-party `scripts/` cannot change under us. Several
  # of these skills ship executable Python and ask for `allowed-tools: Bash`.
  scientific-agent-skills = pkgs.fetchFromGitHub {
    owner = "K-Dense-AI";
    repo = "scientific-agent-skills";
    rev = "v2.65.0";
    sparseCheckout = map (n: "skills/${n}") quantitative;
    hash = "sha256-KL8kSISSV8wBMI/x+xydWWkL3q9sqbpr587aff+NuvM=";
  };

  superpowers = pkgs.fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = "v6.3.0";
    sparseCheckout = map (n: "skills/${n}") methodology;
    hash = "sha256-pQlFMnIihLMGEfvOxG1DQlT7y/mA9qt7fAq0L8flA/U=";
  };

  # Ours. writing-plans is upstream's, edited to strip every instruction to
  # commit and to end each task at a review checkpoint instead - the one change
  # that makes it usable under the Git rules. diff-metrics is ours outright: it
  # measures a change with scb-check, bca and lizard. condense-comments is ours
  # too: it trims comment bloat, and the survey.nu beside it ranks where that
  # bloat is. ./skills/ is where hand-written skills go; NOTICE records what was
  # changed and carries upstream's MIT.
  # orx is the shim `orx install-skills` would write into ~/.claude/skills/,
  # carried here instead because that directory is generated. It is a pointer,
  # not a manual: it tells the agent to run `orx skill`, which prints the real
  # guide out of the installed binary, so it cannot drift from the CLI version.
  #
  # Deliberately not the eleven modules of `--full`. They are always-listed, and
  # this file's whole premise is that the description listing is a budget -
  # eleven orx entries would crowd the sixteen below for a tool used in a
  # fraction of sessions. Upstream defaults to the shim alone for this reason.
  local = {
    writing-plans = ./skills/writing-plans;
    orx = ./skills/orx;
    diff-metrics = ./skills/diff-metrics;
    condense-comments = ./skills/condense-comments;
  };

  # Built into its package with the script paths pinned to the store, so the
  # skill and the binary it launches can never be different versions.
  revdiff = pkgs.callPackage ../../packages/ai/revdiff.nix { };
  hyperresearch = pkgs.callPackage ../../packages/ai/hyperresearch.nix { };

  # Both modules resolve a store-path string to a whole skill directory.
  fromRepo =
    src: names:
    builtins.listToAttrs (
      map (n: {
        name = n;
        value = "${src}/skills/${n}";
      }) names
    );
in
fromRepo scientific-agent-skills quantitative
// fromRepo superpowers methodology
// local
// {
  revdiff = "${revdiff}/share/revdiff/skill";
  deep-research = "${hyperresearch}/share/hyperresearch/skill";

  # The `codex` variant of upstream's skill rather than `default`, for the same
  # reason revdiff takes its codex one: it is the only variant that carries the
  # paragraph about running the CLI with escalated permissions, which holds under
  # codex's sandbox here too. `terminal-browser setup` would install this same
  # file into the agents' generated skill directories - declared here instead.
  terminal-browser = "${pkgs.terminal-browser}/lib/terminal-browser/skills/codex/terminal-browser";

  # herdr's own skill: it teaches an agent running inside a herdr pane to drive
  # that session through the CLI, and refuses to do anything outside one (it
  # checks HERDR_ENV). The derivation ships the agent integrations but not this
  # file, so it comes out of the release source the binary was built from - the
  # same pin, so the two cannot drift.
  herdr = "${pkgs.herdr.src}/skills/herdr";
}
