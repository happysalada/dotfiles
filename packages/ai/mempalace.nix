# MemPalace - local long-term memory for agents, exposed over MCP.
#
# Not in nixpkgs (the only near-miss on the name is `moonpalace`), so it is
# built here. Upstream ships a plain hatchling wheel and every runtime
# dependency is already in nixpkgs, which keeps this derivation boring.
{
  lib,
  python3Packages,
  fetchFromGitHub,
}:

python3Packages.buildPythonApplication rec {
  pname = "mempalace";
  version = "3.8.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "MemPalace";
    repo = "mempalace";
    tag = "v${version}";
    hash = "sha256-NZ2T5yAmQ1qX+HuHuBX3Es846hFj6D1E6j5uSAtK0iQ=";
  };

  build-system = [ python3Packages.hatchling ];

  dependencies = with python3Packages; [
    chromadb
    pyyaml
    huggingface-hub
    tokenizers
    numpy
    python-dateutil
  ];

  # The test suite wants network (it lazy-downloads a 300 MB ONNX embedding
  # model on first use) and a writable HOME. Import check below is enough to
  # catch a broken dependency closure.
  doCheck = false;

  pythonImportsCheck = [ "mempalace" ];

  meta = {
    description = "Local long-term memory system for AI agents, with MCP integration";
    homepage = "https://github.com/MemPalace/mempalace";
    changelog = "https://github.com/MemPalace/mempalace/blob/v${version}/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "mempalace";
    platforms = lib.platforms.unix;
  };
}
