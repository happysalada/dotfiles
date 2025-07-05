{ config, ... }:

{

  networking.firewall.allowedTCPPorts = [
    53
    853
    # 8443
  ];

  networking.firewall.allowedUDPPorts = [
    53
    853
    # 8443
  ];

  services.caddy.virtualHosts = {
    "adgh.megzari.com" = {
      extraConfig = ''
        encode gzip
        import security_headers
        reverse_proxy 127.0.0.1:${toString config.services.adguardhome.port}

      '';
    };
  };

  services.adguardhome = {
    enable = true;
    extraArgs = [
      # Router knows best, i.e. stop returning 127.0.0.1 for DNS calls for self
      "--no-etc-hosts"
    ];
    # host = "127.0.0.1";
    port = 3007;
    settings = {
      dhcp.enabled = false;
      dns = {
        upstream_dns = [
          "quic://dns.nextdns.io"
          "https://cloudflare-dns.com/dns-query"
          "tls://unfiltered.adguard-dns.com"
          "https://dns10.quad9.net/dns-query"
        ];
        bootstrap_dns = [
          "9.9.9.10"
          "149.112.112.10"
          "2620:fe::10"
          "2620:fe::fe:10"
        ];
        all_servers = true;
        upstream_mode = "parallel";
        cache_optimistic = true;
        use_http3_upstreams = true;
        trusted_proxies = [
          "192.168.2.0/24"
          "127.0.0.1/8"
          "::1/128"
        ];
      };
      # tls = {
      #   enabled = false;
      #   server_name = "adgh.megzari.com";
      #   force_https = false;
      #   port_https = 8443;
      #   port_dns_over_quic = 853;
      #   port_dns_over_tls = 853;
      #   allow_unencrypted_doh = true;
      #   resolve_clients = true;
      #   serve_http3 = true;
      #   theme = "dark";
      # };
      # log.verbose = true;
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
