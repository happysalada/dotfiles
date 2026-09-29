# Subagent roles shared by codex, opencode, claude-code and reasonix. No tool
# reads another's agent format, so each tool's files are rendered from one role.
# Every role inherits the full toolset; its prompt is what keeps it in lane.
{ lib, pkgs }:
let
  # tool :: "claude-code" | "opencode" | "codex" | "reasonix"
  mkAgents = { tool }: lib.mapAttrs render.${tool} roles;

  roles = {
    explorer = {
      description = "Read-only codebase explorer for mapping files, symbols, and execution paths before changes.";
      tier = "fast";
      effort = "medium";
      prompt = ''
        Stay in exploration mode. Trace the real execution path with targeted
        searches and file reads, cite exact files and symbols, and return a
        concise evidence summary. Do not propose speculative fixes, edit files,
        or delegate.
      '';
    };

    worker = {
      description = "Implementation worker for one bounded change after the desired behavior is understood.";
      tier = "fast";
      effort = "medium";
      prompt = ''
        Implement only the bounded task assigned by the primary thread. Make the
        smallest defensible change, preserve unrelated work, run focused
        verification, and report changed files and results. Do not delegate.
      '';
    };

    reviewer = {
      description = "Read-only reviewer for correctness, security, regressions, and missing tests.";
      tier = "strong";
      effort = "high";
      prompt = ''
        Review like an owner. Lead with concrete findings ordered by severity,
        cite exact files and lines, and prioritize correctness, security,
        behavior regressions, and missing tests. Do not edit or delegate.
      '';
    };
  };

  # No sandbox, permission or tools keys: each agent inherits the parent's.
  render = {
    codex =
      name: role:
      (pkgs.formats.toml { }).generate "codex-agent-${name}" {
        inherit name;
        inherit (role) description;
        model = models.codex.${role.tier};
        model_reasoning_effort = role.effort;
        developer_instructions = role.prompt;
      };

    opencode =
      name: role:
      frontmatter {
        inherit (role) description;
        mode = "subagent";
        model = models.opencode.${role.tier};
        options.reasoningEffort = role.effort;
      } role.prompt;

    claude-code =
      name: role:
      frontmatter {
        inherit name;
        inherit (role) description effort;
        model = models.claude-code.${role.tier};
      } role.prompt;

    # reasonix has no separate agent format of its own: a subagent profile *is*
    # a Skill file carrying `runAs: subagent`, which is exactly what its own
    # `reasonix subagent create` writes. homes/programs/reasonix.nix puts the
    # three under ~/.reasonix/skills/, the global profile root.
    #
    # `invocation: manual` keeps them out of the session-context Skills catalog
    # - the same description-listing budget ai-skills.nix is built around - so a
    # profile costs context only when something actually spawns it.
    #
    # No allowed-tools key, deliberately: a profile-level allowlist would be a
    # second place for the boundary to drift out of step with the prompt, and no
    # other tool's role carries one either.
    reasonix =
      name: role:
      frontmatter {
        inherit name;
        inherit (role) description;
        invocation = "manual";
        runAs = "subagent";
        model = models.reasonix.${role.tier};
        effort = efforts.reasonix.${role.effort};
      } role.prompt;
  };

  # The one place the tools differ. Sonnet is the floor for Claude. Reasonix's
  # two names are the `[[providers]]` names in homes/programs/reasonix.nix, not
  # models.dev ids - it is pointed at DeepSeek directly.
  models = {
    codex = {
      fast = "gpt-6-luna";
      strong = "gpt-6-sol";
    };
    opencode = {
      fast = "openai/gpt-5.6-terra";
      strong = "openai/gpt-5.6-sol";
    };
    claude-code = {
      fast = "sonnet";
      strong = "opus";
    };
    reasonix = {
      fast = "deepseek-flash";
      strong = "deepseek-pro";
    };
  };

  # reasonix's effort enum is per provider, and the DeepSeek providers in
  # homes/programs/reasonix.nix declare disabled|low|high|max - there is no
  # "medium", and a value outside `supported_efforts` is a doctor warning
  # rather than an error. So the role's effort maps by relative position: the
  # fast tier gets the cheap thinking level, the strong tier the provider
  # default. Only reasonix needs the translation; the rest take it verbatim.
  efforts = {
    reasonix = {
      medium = "low";
      high = "high";
    };
  };

  frontmatter = attrs: body: ''
    ---
    ${yaml attrs}
    ---

    ${body}'';

  # Scalars are JSON-quoted, which YAML reads as plain strings.
  yaml = attrs: lib.concatStringsSep "\n" (lib.mapAttrsToList yamlEntry attrs);

  yamlEntry =
    key: value:
    if lib.isAttrs value then
      "${key}:\n" + lib.concatMapStringsSep "\n" (line: "  ${line}") (lib.splitString "\n" (yaml value))
    else
      "${key}: ${builtins.toJSON value}";
in
{
  inherit mkAgents;
}
