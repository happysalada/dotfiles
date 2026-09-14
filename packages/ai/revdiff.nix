# revdiff - TUI for commenting on a diff line by line. On quit it prints the
# comments as `## file:line (+)` markdown, which is what the agent reads back.
#
# Not in nixpkgs (checked 2026-09-14), so it is built here from the GitHub tag.
# Upstream commits vendor/, so there is no vendorHash to chase.
#
# The same derivation carries the agent skill under share/revdiff/skill, which
# homes/programs/ai-skills.nix registers for claude-code, codex and opencode.
# Do NOT run `/plugin install revdiff@revdiff`, `codex plugin add` or upstream's
# plugins/opencode/setup.sh - each writes into config this repo generates.
{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGoModule (finalAttrs: {
  pname = "revdiff";
  version = "1.13.0";

  src = fetchFromGitHub {
    owner = "umputun";
    repo = "revdiff";
    tag = "v${finalAttrs.version}";
    hash = "sha256-qcah2Fx4u9AXEfb22R9BW3Rv9oYx+H8+KPGQVRjOr98=";
  };

  vendorHash = null;
  subPackages = [ "app" ];
  env.CGO_ENABLED = 0;
  ldflags = [
    "-s"
    "-w"
    "-X main.revision=${finalAttrs.version}"
  ];

  # The suite needs a git working tree, which the sandbox does not have.
  doCheck = false;

  # Upstream ships a Claude and a Codex variant of the skill. The Codex one is
  # taken because the Claude one leans on plan mode and AskUserQuestion, which
  # codex and opencode lack. Its scripts are pinned to the store, so no agent
  # has to work out a plugin root, and the launcher to this exact binary.
  postInstall = ''
    mv $out/bin/app $out/bin/revdiff

    skill=$out/share/revdiff/skill
    mkdir -p $skill/scripts $skill/references
    cp plugins/codex/skills/revdiff/SKILL.md $skill/
    cp .claude-plugin/skills/revdiff/references/{config,usage}.md $skill/references/
    cp .claude-plugin/skills/revdiff/scripts/{launch-revdiff,detect-ref,read-latest-history,agentdeck-window}.sh \
      $skill/scripts/

    sed -i '/^## Script Path Resolution$/,/^## Activation Triggers$/{/^## Activation Triggers$/!d}' \
      $skill/SKILL.md
    substituteInPlace $skill/SKILL.md \
      --replace-fail '$SCRIPT_DIR' "$skill/scripts" \
      --replace-fail 'wants Codex to' 'wants you to' \
      --replace-fail 'Codex reads' 'the agent reads' \
      --replace-fail 'Codex refines' 'the agent refines'
    if grep -q 'plugin-root\|CLAUDE_' $skill/SKILL.md; then
      echo "revdiff SKILL.md still resolves paths through a plugin" >&2
      exit 1
    fi

    substituteInPlace $skill/scripts/launch-revdiff.sh \
      --replace-fail 'REVDIFF_BIN=$(command -v revdiff 2>/dev/null || true)' "REVDIFF_BIN=$out/bin/revdiff"

    # Upstream's install.md tells the agent to run the plugin installers.
    cat > $skill/references/install.md <<'EOF'
    # Installation

    revdiff and this skill are installed by nix, from packages/ai/revdiff.nix
    in the dotfiles, and registered in homes/programs/ai-skills.nix. Upgrade by
    bumping the version there.

    Do not run `/plugin install`, `codex plugin add`, upstream's opencode
    setup.sh or `brew install`: they write into generated, read-only config.
    EOF
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";
  doInstallCheck = true;

  meta = {
    description = "TUI for reviewing diffs, files, and documents with inline annotations";
    homepage = "https://github.com/umputun/revdiff";
    changelog = "https://github.com/umputun/revdiff/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "revdiff";
    platforms = lib.platforms.unix;
  };
})
