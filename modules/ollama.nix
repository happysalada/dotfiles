{ ... }:

{
  # Upstream removed `services.ollama.acceleration`: the backend is chosen by
  # the package now. So each machine importing this sets its own `package`
  # (bee: ollama-rocm, strix: ollama-cuda) and its own `loadModels` - a server
  # pulling embedding models is not what a laptop wants.
  services.ollama = {
    enable = true;

    # Shrinks the KV cache and keeps long prompts cheap. Both the rocm and the
    # cuda backend honour it.
    environmentVariables.OLLAMA_FLASH_ATTENTION = "1";
  };
}
