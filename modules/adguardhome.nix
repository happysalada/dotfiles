{ ... }:

{
  services.adguardhome = {
    enable = true;
    host = "127.0.0.1";
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
      };
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
}
