# `scb-check` reports the two SlopCodeBench metrics - verbosity and erosion -
# for Python, Rust, JavaScript, TypeScript, Zig, Haskell and C++. The paper's own
# harness shells out to this same CLI (`uvx scb-check==V check --report PATH`),
# so the numbers here are the published ones rather than a reimplementation.
{
  ast-grep,
  fetchFromGitHub,
  lib,
  makeWrapper,
  python3Packages,
}:

let
  # scb-check imports all seven grammars eagerly from
  # tree_walking/languages/registry.py, so a missing one is a hard ImportError.
  # nixpkgs carries the Python bindings for Rust, Python, JS and TS only; these
  # three are the same 20-line shape as nixpkgs' tree-sitter-rust.
  grammar =
    { owner ? "tree-sitter", pname, version, module, hash }:
    python3Packages.buildPythonPackage {
      inherit pname version;
      pyproject = true;

      src = fetchFromGitHub {
        inherit owner hash;
        repo = pname;
        tag = "v${version}";
      };

      build-system = [ python3Packages.setuptools ];

      # Grammar repos ship no Python tests.
      doCheck = false;
      pythonImportsCheck = [ module ];
    };
in
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "scb-check";
  version = "0.2.0";
  pyproject = true;

  src = python3Packages.fetchPypi {
    # PyPI stores the sdist under the normalised name, with an underscore.
    pname = "scb_check";
    inherit (finalAttrs) version;
    hash = "sha256-sdUi+0lU3IY+7vexh23KLw/QsLRDoepRp0R5pkPiCbs=";
  };

  build-system = [ python3Packages.hatchling ];

  dependencies = with python3Packages; [
    pydantic
    pyyaml
    structlog
    tree-sitter
    tree-sitter-javascript
    tree-sitter-python
    tree-sitter-rust
    tree-sitter-typescript
    typer
    (grammar {
      pname = "tree-sitter-cpp";
      version = "0.23.4";
      module = "tree_sitter_cpp";
      hash = "sha256-tP5Tu747V8QMCEBYwOEmMQUm8OjojpJdlRmjcJTbe2k=";
    })
    (grammar {
      pname = "tree-sitter-haskell";
      version = "0.23.1";
      module = "tree_sitter_haskell";
      hash = "sha256-bggXKbV4vTWapQAbERPUszxpQtpC1RTujNhwgbjY7T4=";
    })
    (grammar {
      owner = "tree-sitter-grammars";
      pname = "tree-sitter-zig";
      version = "1.1.2";
      module = "tree_sitter_zig";
      hash = "sha256-lDMmnmeGr2ti9W692ZqySWObzSUa9vY7f+oHZiE8N+U=";
    })
  ];

  # Upstream pins every dependency with `==`; nixpkgs tracks its own versions.
  pythonRelaxDeps = true;

  # ast-grep-cli is a wheel carrying a Rust binary. nixpkgs already ships
  # ast-grep, so this is dropped and picked up from PATH instead - see the
  # substitute below, which is also what stops NixOS's setgid `sg` utility being
  # mistaken for ast-grep's own `sg` alias.
  pythonRemoveDeps = [ "ast-grep-cli" ];

  postPatch = ''
    substituteInPlace src/scb_check/analysis/astgrep.py \
      --replace-fail 'shutil.which("sg")' 'shutil.which("ast-grep")'

    # The build backend is pinned exactly as well; nixpkgs tracks its own
    # hatchling, and pythonRelaxDeps only touches the runtime requirements.
    substituteInPlace pyproject.toml \
      --replace-fail 'hatchling==1.27.0' 'hatchling'

    # ast-grep is filtered to Python before it is ever invoked, so the Rust rules
    # shipped below would be loaded and then never applied to a .rs file. Each
    # substitution is one whole line, and --replace-fail turns an upstream
    # reshuffle into a build failure rather than a silent zero.
    substituteInPlace src/scb_check/pipeline.py \
      --replace-fail 'python_files = _files_by_language(sources, Language.PYTHON)' \
                     'scanned_files = (*_files_by_language(sources, Language.PYTHON), *_files_by_language(sources, Language.RUST))' \
      --replace-fail 'if disable_sg or not python_files:' \
                     'if disable_sg or not scanned_files:' \
      --replace-fail 'run_sg(python_files, rules_path),' \
                     'run_sg(scanned_files, rules_path),'

    cp ${./scb-check-rust-rules.yaml} src/scb_check/resources/slop_rules/rust.yaml
  '';

  nativeBuildInputs = [ makeWrapper ];

  # The lookup above is a PATH search, and ast-grep is not otherwise in the
  # wrapper's environment.
  postFixup = ''
    wrapProgram $out/bin/scb-check \
      --prefix PATH : ${lib.makeBinPath [ ast-grep ]}
  '';

  # Upstream's suite is snapshot-based and needs pytest-snapshot fixtures that
  # are not wired here; pythonImportsCheck still exercises every grammar import.
  doCheck = false;
  pythonImportsCheck = [ "scb_check" ];

  meta = {
    description = "Measure verbosity and structural erosion in a codebase";
    homepage = "https://github.com/gabeorlanski/scb-check";
    license = lib.licenses.mit;
    mainProgram = "scb-check";
  };
})
