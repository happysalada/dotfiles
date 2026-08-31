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
  # outright. executing-plans goes with them - it carries a "REQUIRED SUB-SKILL"
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
  # that makes it usable under the Git rules. ./skills/ is where hand-written
  # skills go; NOTICE records what was changed and carries upstream's MIT.
  local = {
    writing-plans = ./skills/writing-plans;
  };

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
fromRepo scientific-agent-skills quantitative // fromRepo superpowers methodology // local
