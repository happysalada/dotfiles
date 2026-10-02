# hyperresearch - deep research pipeline for coding agents: a 16-step,
# adversarially audited run that writes a cited report, plus a markdown +
# SQLite vault of every source it read. `hyperresearch` and `hpr` are the CLI.
#
# Built from GitHub, not PyPI: Codex support is on main but not released yet.
#
# The same derivation carries upstream's `deep-research` skill under
# share/hyperresearch/skill, which homes/programs/ai-skills.nix registers for
# claude-code, codex and opencode. First use installs the pipeline into the
# project's .claude/ or .agents/, never into the generated files under ~/.
{
  lib,
  python3Packages,
  fetchFromGitHub,
}:

python3Packages.buildPythonApplication {
  pname = "hyperresearch";
  version = "0.12.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "jordan-gibbs";
    repo = "hyperresearch";
    rev = "6bae23c735c51b5df73cd1d89010588301dc8804";
    hash = "sha256-KEtu7dkfbJpIgWZG0Ksp993oo0LksLqOKZYD5cF8hLc=";
  };

  build-system = [ python3Packages.hatchling ];

  dependencies = with python3Packages; [
    typer
    rich
    pyyaml
    pydantic
    jinja2
    platformdirs
    pymupdf
    httpx
  ];

  # Only the opt-in `crawl4ai` web provider imports it, and that provider also
  # wants Playwright's downloaded Chromium, which NixOS cannot run. The default
  # `builtin` provider needs neither.
  pythonRemoveDeps = [ "crawl4ai" ];

  # Upstream's skill points at pip and knows only Claude Code and Codex.
  postInstall = ''
    skill=$out/share/hyperresearch/skill
    install -Dm444 skills/deep-research/SKILL.md $skill/SKILL.md

    substituteInPlace $skill/SKILL.md \
      --replace-fail 'Requires Python 3.11+ and the hyperresearch CLI (pip install hyperresearch), plus' \
        'Requires the hyperresearch CLI (installed by nix), plus' \
      --replace-fail '> hyperresearch is not installed. Install it with `pip install hyperresearch`' \
        '> hyperresearch is not on PATH. It is installed by nix, from' \
      --replace-fail '> (Python 3.11 to 3.14), then ask again.' \
        '> packages/ai/hyperresearch.nix in the dotfiles; rebuild, then ask again.' \
      --replace-fail 'You may run `pip install hyperresearch` yourself only if the user says to.' \
        'Never run `pip install hyperresearch` or `hyperresearch install --global`: the
    first shadows the nix build, the second writes into generated config under ~/.' \
      --replace-fail '  and skills are invoked as `$name`): section 3B.' \
        '  and skills are invoked as `$name`): section 3B.
    - **opencode**: section 3B, even though you have a skill and a task tool.
      Where a step file says to spawn a custom agent, read its instructions from
      `.codex/agents/<name>.toml` and pass them to a general subagent instead.'
    if grep -q 'pip install hyperresearch`$\|Install it with' $skill/SKILL.md; then
      echo "hyperresearch SKILL.md still tells the agent to pip install" >&2
      exit 1
    fi
  '';

  pythonImportsCheck = [
    "hyperresearch"
    "hyperresearch.cli"
  ];

  meta = {
    description = "Deep research harness for Claude Code and Codex with a persistent source vault";
    homepage = "https://github.com/jordan-gibbs/hyperresearch";
    license = lib.licenses.mit;
    mainProgram = "hyperresearch";
    platforms = lib.platforms.unix;
  };
}
