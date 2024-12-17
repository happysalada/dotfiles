{ ... }:

{
  services.ollama = {
    enable = true;
    loadModels = [
      "mistral-nemo"
      "bge-m3" # for embeddings
      "paraphrase-multilingual" # for reranking with sentence transformers
    ];
    acceleration = "rocm";
    environmentVariables = {
      OLLAMA_FLASH_ATTENTION = "1";
    };
  };
}
