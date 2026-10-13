# Agent skills, shared by claude-code and opencode. Both take the same
# `name -> store path` shape, so one attrset feeds both.
#
# Cherry-picked, never whole repos: Claude Code budgets the description listing
# at 1% of the context window and drops the least-invoked on overflow, so all
# 165 scientific skills would make the eleven below harder to match, not easier
# - and cost 248MB of closure instead of 3.5MB.
{ pkgs }:
let
  # The domain-neutral quantitative core of an otherwise-bioinformatics repo;
  # deliberately no genomics or cheminformatics.
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
  # agent to stage and commit, which the Git section of ai-context.nix forbids,
  # and to make worktrees, which it allows only when asked. executing-plans
  # carries a "REQUIRED SUB-SKILL" pointer into that pair, so taking it would
  # smuggle the commit workflow back in. The five below reference only each
  # other. writing-plans had the same problem and is vendored instead, below.
  methodology = [
    "brainstorming"
    "receiving-code-review"
    "systematic-debugging"
    "test-driven-development"
    "verification-before-completion"
  ];

  # Pinned by tag, so an upgrade is a reviewable diff and third-party `scripts/`
  # cannot change under us. Several ship executable Python asking for Bash.
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

  # The anti-slop design skill for public-facing pages: it deals one of twenty
  # researched art directions instead of letting the model pick the category
  # default, then checks its own work in a real browser.
  #
  # One of fourteen skills in that repo, and the only one taken. The rest are
  # image-generation-only (brandkit, imagegen-frontend-web/mobile), model-specific
  # (gpt-taste) or narrower variants (minimalist, brutalist, soft, redesign,
  # output, stitch), and every one of them is another description competing for
  # the 1% listing budget above.
  #
  # Pinned by tag for the same reason as the two above, and it matters more
  # here: scripts/ is Node the agent runs with Bash, and scripts/inspect.mjs
  # drives a real Chrome over the DevTools protocol to measure the page. Its
  # scripts/lib/cdp.mjs reads CHROME_PATH (or PUPPETEER_EXECUTABLE_PATH) before
  # its list of well-known paths - which is why machines/strix/default.nix sets
  # it; /usr/bin/chromium, the one Linux path it does probe, does not exist on
  # NixOS. Node 22+ comes from nodejs-slim in packages/ai.nix.
  #
  # 1.7MB, most of it the direction library under library/.
  taste = pkgs.fetchFromGitHub {
    owner = "Leonxlnx";
    repo = "taste-skill";
    rev = "v2.0.0";
    sparseCheckout = [ "skills/taste-skill" ];
    hash = "sha256-EnawE8tQRGP5Oodn+8TP/rB1+bemdKIGaQO0WCIC9u0=";
  };

  # Ours, plus one vendored. writing-plans is upstream's, edited to strip every
  # instruction to commit and end each task at a review checkpoint - the change
  # that makes it usable under the Git rules. diff-metrics measures a change with
  # scb-check, bca and lizard; condense-comments trims comment bloat (survey.nu
  # ranks where). ./skills/ holds hand-written skills; NOTICE records what changed
  # and carries upstream's MIT.
  #
  # orx is the shim `orx install-skills` would write into ~/.claude/skills/,
  # carried here because that directory is generated. It is a pointer, not a
  # manual: it tells the agent to run `orx skill`, which prints the real guide
  # out of the installed binary, so it cannot drift from the CLI version.
  #
  # cli-toolbox holds the installed tools whose job is not guessable from the
  # name. A skill rather than more prose because the always-on Tooling table in
  # ai-context.nix carries only the substitutions, and the rest of the toolbox
  # is worth loading in full only for the task that needs it.
  #
  # Deliberately not the eleven modules of `--full`: always-listed, they would
  # crowd the sixteen below. Upstream defaults to the shim alone for the same
  # reason.
  local = {
    writing-plans = ./skills/writing-plans;
    orx = ./skills/orx;
    diff-metrics = ./skills/diff-metrics;
    condense-comments = ./skills/condense-comments;
    cli-toolbox = ./skills/cli-toolbox;
  };

  # Built into its package with the script paths pinned to the store, so the
  # skill and its binary can never be different versions.
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

  # The `codex` variant, not `default`, for the same reason revdiff takes its
  # codex one: only it carries the escalated-permissions paragraph, which holds
  # under codex's sandbox here too. `terminal-browser setup` would install this
  # same file into the agents' generated dirs - declared here instead.
  terminal-browser = "${pkgs.terminal-browser}/lib/terminal-browser/skills/codex/terminal-browser";

  # herdr's own skill: it teaches an agent in a herdr pane to drive that session
  # through the CLI and refuses to act outside one (checks HERDR_ENV). The
  # derivation ships the integrations but not this file, so it comes from the
  # release source the binary was built from - the same pin, so they cannot drift.
  herdr = "${pkgs.herdr.src}/skills/herdr";

  # The key is the skill's own frontmatter `name`, not the folder it came from:
  # v2 renamed the skill to design-taste-frontend while the directory under
  # skills/ stayed taste-skill, and an agent resolves a skill by that name, so
  # the installed directory has to carry it.
  design-taste-frontend = "${taste}/skills/taste-skill";
}
