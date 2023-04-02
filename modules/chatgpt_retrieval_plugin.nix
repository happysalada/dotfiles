{ config, lib, pkgs, ... }:

{
  services.chatgpt-retrieval-plugin = {
    enable = true;
    bearerTokenPath = config.age.secrets.CHATGPT_RETRIEVAL_PLUGIN_BEARER_TOKEN.path;
    openaiApiKeyPath = config.age.secrets.OPENAI_KEY.path;
    qdrantCollection = "gc_first_test";
  };

  age.secrets =  {
    CHATGPT_RETRIEVAL_PLUGIN_BEARER_TOKEN = {
      file = ../secrets/chatgpt_retrieval_plugin.bearer_token.age;
    };
    OPENAI_KEY = {
      file = ../secrets/openai.key.age;
    };
  };

  services.caddy.virtualHosts."chatgpt_retrieval_plugin.sassy.technology" = {
    extraConfig = ''
      reverse_proxy 127.0.0.1:${toString config.services.chatgpt-retrieval-plugin.port}
    '';
  };
}
