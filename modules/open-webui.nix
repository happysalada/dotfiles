{ config, ... }:

{
  services.open-webui = {
    enable = true;
    environment = {
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
      # # Disable authentication
      # WEBUI_AUTH = "False";
      # web search
      TASK_MODEL = "mistral-nemo";
      ENABLE_RAG_WEB_SEARCH = "True";
      ENABLE_SEARCH_QUERY = "True";
      ENABLE_RAG_LOCAL_WEB_FETCH = "True";
      RAG_WEB_SEARCH_ENGINE = "searxng";
      RAG_WEB_SEARCH_RESULT_COUNT = "10";
      RAG_WEB_SEARCH_CONCURRENT_REQUESTS = "10";
      SEARXNG_QUERY_URL = "http://localhost:8889/search?q=<query>";

      # RAG
      RAG_TOP_K = "10";
      RAG_EMBEDDING_ENGINE = "ollama";
      RAG_EMBEDDING_MODEL = "bge-m3";
      RAG_RERANKING_MODEL = "linux6200/bge-reranker-v2-m3";
      CHUNK_SIZE = "8000"; # default 1500
      ENABLE_RAG_HYBRID_SEARCH = "True";

      AUDIO_STT_ENGINE = "openai";
    };
  };

  services.caddy.virtualHosts = {
    "owu.megzari.com" = {
      extraConfig = ''
        import security_headers
        reverse_proxy 127.0.0.1:${toString config.services.open-webui.port}
      '';
    };
  };
}
