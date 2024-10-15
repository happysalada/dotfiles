{ config, ... }:

{
  services.adguardhome = {
    enable = true;
    host = "127.0.0.1";
    port = 3007;
    settings = {
      dns = {
        upstream_dns = [
          "quic://dns.nextdns.io"
          "https://cloudflare-dns.com/dns-query"
          "tls://unfiltered.adguard-dns.com"
        ];
        all_servers = true;
        upstream_mode = "parallel";
        cache_optimistic = true;
        trusted_proxies = [
          "192.168.2.0/24"
          "127.0.0.1/8"
          # Cloudflare Ips
          "103.21.244.0/22"
          "103.22.200.0/22"
          "103.31.4.0/22"
          "104.16.0.0/13"
          "104.24.0.0/14"
          "108.162.192.0/18"
          "131.0.72.0/22"
          "141.101.64.0/18"
          "162.158.0.0/15"
          "172.64.0.0/13"
          "173.245.48.0/20"
          "188.114.96.0/20"
          "190.93.240.0/20"
          "197.234.240.0/22"
          "198.41.128.0/17"
        ];
      };
      tls = {
        enabled = true;
        server_name = "adgh.megzari.com";
        force_https = false;
        port_https = 8443;
        port_dns_over_quic = 853;
        port_dns_over_tls = 853;
        allow_unencrypted_doh = true;
      };
      theme = "dark";
      filters =
        map
          (url: {
            enabled = true;
            url = url;
          })
          [
            "https://small.oisd.nl" # oisd
            "https://big.oisd.nl" # oisd
            "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt" # The Big List of Hacked Malware Web Sites
            "https://adguardteam.github.io/HostlistsRegistry/assets/filter_11.txt" # malicious url blocklist
          ];
    };
  };
  services.caddy.virtualHosts = {
    "adgh.megzari.com" = {
      extraConfig = ''
        import security_headers
        reverse_proxy 127.0.0.1:${toString config.services.adguardhome.port}
      '';
    };
  };
}
