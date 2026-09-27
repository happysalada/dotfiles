# DeepTutor - agent-native tutoring app: chat, RAG knowledge bases, quizzes,
# guided reading. `deeptutor start` serves API + web UI; `deeptutor chat` is
# the terminal REPL.
#
# Built from the PyPI wheel rather than the GitHub source, because the wheel
# carries the prebuilt Next.js standalone server under deeptutor_web/. The
# source tree has only web/, which would mean a buildNpmPackage for the UI.
#
# Runtime data lands in the *current directory* unless DEEPTUTOR_HOME is set -
# upstream treats each directory as a workspace, like git, so that is kept.
{
  lib,
  python3Packages,
  fetchPypi,
  nodejs,
  autoPatchelfHook,
  stdenv,
}:

let
  deeptutor = python3Packages.buildPythonApplication rec {
    pname = "deeptutor";
    version = "1.6.12";
    format = "wheel";

    src = fetchPypi {
      inherit pname version;
      format = "wheel";
      dist = "py3";
      python = "py3";
      hash = "sha256-wHrhm8e3NMzbaqMr4LK4W5wvtVZJvRCiMo4MvhW92Ao=";
    };

    # The launcher copies the packaged web app out of site-packages and then
    # rewrites placeholders in it. copytree keeps the store's 0444/0555 modes,
    # so that rewrite - and the rmtree on the next upgrade - would fail.
    postInstall = ''
      substituteInPlace $out/${python3Packages.python.sitePackages}/deeptutor/runtime/launcher.py \
        --replace-fail \
          '    shutil.copytree(packaged, cache)' \
          '    shutil.copytree(packaged, cache)
          for p in [cache, *cache.rglob("*")]:
              if not p.is_symlink():
                  p.chmod(p.stat().st_mode | 0o200)'

      # sharp ships glibc and musl builds side by side; only glibc can load here.
      rm -r $out/${python3Packages.python.sitePackages}/deeptutor_web/node_modules/@img/*musl*
    '';

    # For sharp's prebuilt addon and libvips, used by Next image optimisation.
    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib ];

    # The launcher spawns the backend and its workers as `sys.executable -m ...`.
    # That bare interpreter lacks the site-packages the entry script injects,
    # so they have to arrive through the environment instead.
    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath [ nodejs ])
      "--prefix"
      "PYTHONPATH"
      ":"
      "${placeholder "out"}/${python3Packages.python.sitePackages}:${python3Packages.makePythonPath dependencies}"
    ];

    dependencies =
      with python3Packages;
      [
        pyyaml
        jinja2
        openai
        tiktoken
        aiohttp
        httpx
        requests
        ddgs
        nest-asyncio
        tenacity
        pydantic
        pydantic-settings
        jsonschema
        aiosqlite
        typer
        rich
        prompt-toolkit
        pyte
        mcp
        qrcode
        anthropic
        dashscope
        perplexityai
        llama-index
        llama-index-vector-stores-faiss
        faiss
        pymupdf
        pillow
        numpy
        arxiv
        python-docx
        openpyxl
        python-pptx
        pypdf
        pdfplumber
        reportlab
        defusedxml
        youtube-transcript-api
        fastapi
        uvicorn
        websockets
        python-multipart
        bcrypt
        python-jose
        redis
        loguru
        json-repair
        croniter
        psutil
      ]
      ++ [
        pageindex
        oauth-cli-kit
        pocketbase
      ]
      ++ uvicorn.optional-dependencies.standard
      ++ python-jose.optional-dependencies.cryptography;

    # nixpkgs is ahead of upstream's caps on redis and behind its floor on
    # json-repair; neither API change touches what deeptutor calls.
    pythonRelaxDeps = [
      "redis"
      "json-repair"
    ];

    # PyPI's wheel is named faiss-cpu; nixpkgs' `faiss` provides the same module.
    pythonRemoveDeps = [ "faiss-cpu" ];

    # Imports the whole service graph, which is the check that matters for a
    # wheel: a missing or incompatible dependency fails here, not at first run.
    pythonImportsCheck = [
      "deeptutor"
      "deeptutor_cli.main"
      "deeptutor.api.main"
    ];

    meta = {
      description = "Agent-native personalized tutoring with multi-agent RAG";
      homepage = "https://github.com/HKUDS/DeepTutor";
      changelog = "https://github.com/HKUDS/DeepTutor/releases/tag/v${version}";
      license = lib.licenses.asl20;
      mainProgram = "deeptutor";
      platforms = [ "x86_64-linux" ];
    };
  };

  # The three dependencies nixpkgs does not have. All pure python.

  pageindex = python3Packages.buildPythonPackage rec {
    pname = "pageindex";
    version = "0.2.19";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-hD8jqHHXYlPBlvkqC9oNTX+RzAV1ru/xnpb65VbwWmc=";
    };

    # PyPDF2 is marked insecure in nixpkgs. pypdf is its maintained successor
    # with the same snake_case API, which is all pageindex calls.
    postPatch = ''
      substituteInPlace pyproject.toml --replace-fail 'PyPDF2 = ">=3.0.0"' 'pypdf = "*"'
      # Imports only: "PyPDF2" is also a pdf_parser option string callers pass.
      find pageindex -name '*.py' -exec sed -i \
        -e 's/import PyPDF2 as /import pypdf as /' \
        -e 's/import PyPDF2$/import pypdf as PyPDF2/' \
        -e 's/from PyPDF2\./from pypdf./' {} +
    '';

    build-system = [ python3Packages.poetry-core ];

    dependencies = with python3Packages; [
      pillow
      pypdf
      litellm
      mcp
      openai
      openai-agents'
      pypdfium2
      python-dotenv
      pyyaml
      regex
      requests
      sortedcontainers
      urllib3
    ];

    pythonImportsCheck = [ "pageindex" ];

    meta = {
      description = "Vectorless, reasoning-based RAG over long documents";
      homepage = "https://github.com/VectifyAI/PageIndex";
      license = lib.licenses.mit;
    };
  };

  # nixpkgs' 0.18.1 fails its runtime-deps check: upstream added websockets
  # and the derivation never declared it.
  openai-agents' = python3Packages.openai-agents.overridePythonAttrs (old: {
    dependencies = old.dependencies ++ [ python3Packages.websockets ];
  });

  oauth-cli-kit = python3Packages.buildPythonPackage rec {
    pname = "oauth-cli-kit";
    version = "0.1.6";
    pyproject = true;

    src = fetchPypi {
      pname = "oauth_cli_kit";
      inherit version;
      hash = "sha256-clL1fhovnbp6lIlMEbl5+DiEs8iK87T+AgY3CisSBJk=";
    };

    build-system = with python3Packages; [
      hatchling
      hatch-vcs
    ];

    dependencies = with python3Packages; [
      httpx
      platformdirs
    ];

    pythonImportsCheck = [ "oauth_cli_kit" ];

    meta = {
      description = "OAuth PKCE login helpers for CLI tools";
      homepage = "https://pypi.org/project/oauth-cli-kit/";
      license = lib.licenses.mit;
    };
  };

  pocketbase = python3Packages.buildPythonPackage rec {
    pname = "pocketbase";
    version = "0.17.3";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-Ed5NQS/dyY5yAw+nizlZcuqmRsNsBqolBtiibNJRywA=";
    };

    build-system = [ python3Packages.uv-build ];

    dependencies = [ python3Packages.httpx ];

    pythonImportsCheck = [ "pocketbase" ];

    meta = {
      description = "PocketBase client SDK for Python";
      homepage = "https://github.com/vaphes/pocketbase";
      license = lib.licenses.mit;
    };
  };
in
deeptutor
