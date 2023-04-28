{
  systemd.services.vector.requires = [ "loki.service" ];
  systemd.services.vector.after = [ "loki.service" ];

  services.vector = {
    enable = true;
    journaldAccess = true;
    settings = {
      # api = {
      #   enabled = true;
      #   address = "127.0.0.1:8686"; # is the default, added just to make it clear
      # };
      sources.journald.type = "journald";

      transforms.modify = {
        type = "remap"; # required
        inputs = ["journald"]; # required                         
        source = ''
          del(.PRIORITY)
          del(.SYSLOG_FACILITY)
          del(.SYSLOG_PID)
          del(.SYSLOG_TIMESTAMP)
          del(.SYSLOG_IDENTIFIER)
          del(._SELINUX_CONTEXT)
          del(._AUDIT_LOGINUID)
          del(._AUDIT_SESSION)
          del(._BOOT_ID)
          del(._CAP_EFFECTIVE)
          del(._CMDLINE)
          del(._COMM)
          del(._EXE)
          del(._GID)
          del(._MACHINE_ID)
          del(._PID)
          del(._SOURCE_MONOTONIC_TIMESTAMP)
          del(._SOURCE_REALTIME_TIMESTAMP)
          del(._STREAM_ID)
          del(._SYSTEMD_CGROUP)
          del(._SYSTEMD_INVOCATION_ID)
          del(._SYSTEMD_SLICE)
          del(._SYSTEMD_USER_SLICE)
          del(._SYSTEMD_OWNER_UID)
          del(._SYSTEMD_SESSION)
          del(._TRANSPORT)
          del(._UID)
          del(.__MONOTONIC_TIMESTAMP)
          del(.__REALTIME_TIMESTAMP)
          del(.host)
          del(.source_type)
          lvl, err = parse_regex(.message, r'le?ve?l=(?P<lvl>\w+)') 
          if err == null {
            .level = lvl.lvl
          }
          msg, err = parse_regex(.message, r'me?ss?a?ge?=(?P<msg>.+)')
          if err == null {
            .message = msg.msg
          }
          msg, err = parse_json(.message)
          if err == null {
            . = merge!(., msg)
            del(.message)
          }
        '';
      };

      sinks = {

        loki = {
          endpoint = "http://localhost:3100";
          inputs = [ "modify" ];
          type = "loki";
          encoding.codec = "json";
          out_of_order_action = "drop";
          remove_timestamp = true;
          healthcheck.enabled = true;

          # Labels
          labels = {
            level = "{{ level }}";
            systemd_unit = "{{ _SYSTEMD_UNIT }}";
          };
        };
      };
    };
  };

  # services.caddy.virtualHosts."vector.sassy.technology" = {
  #   extraConfig = ''
  #     reverse_proxy 127.0.0.1:8686
  #   '';
  # };
}