# Subagent roles shared by codex, opencode and claude-code. No tool reads
# another's agent format, so each tool's files are rendered from one role.
# Every role inherits the full toolset; its prompt is what keeps it in lane.
{ lib, pkgs }:
let
  # tool :: "claude-code" | "opencode" | "codex"
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
  };

  # The one place the tools differ. Sonnet is the floor for Claude.
  models = {
    codex = {
      fast = "gpt-5.6-terra";
      strong = "gpt-5.6-sol";
    };
    opencode = {
      fast = "openai/gpt-5.6-terra";
      strong = "openai/gpt-5.6-sol";
    };
    claude-code = {
      fast = "sonnet";
      strong = "opus";
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
