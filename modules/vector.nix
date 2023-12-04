{
  systemd.services.vector.requires = [ "loki.service" ];
  systemd.services.vector.after = [ "loki.service" ];

  services.vector = {
    enable = true;
    journaldAccess = true;
    settings = {
      # api.enabled = true; # defaults to port 8686
      sources = {
        journald.type = "journald";
        # http_server = {
        #   type = "http_server";
        #   address = "127.0.0.1:8687";
        #   # decoding.codec = "json";
        # };
      };

      transforms ={
        journald_format = {
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
            del(._RUNTIME_SCOPE)
            del(.__MONOTONIC_TIMESTAMP)
            del(.__REALTIME_TIMESTAMP)
            del(.__SEQNUM)
            del(.__SEQNUM_ID)
            del(.host)
            del(.source_type)
            lvl, err = parse_regex(.message, r'le?ve?l=(?P<lvl>\w+)') 
            if err == null {
              .level = lvl.lvl
            } else {
              .level = "info"
            }
            msg, err = parse_regex(.message, r'me?ss?a?ge?=(?P<msg>.+)')
            if err == null {
              json_message, err = parse_json(.message)
              if err == null {
                # if 'msg' is an object merge it
                if is_object(json_message) {
                    del(.message)
                    . = merge!(., json_message)
                # If 'msg' is a string, just keep it as the message
                } else if is_string(json_message) {
                    .message = json_message
                }
              } else {
                # If JSON parsing fails, keep the original 'msg'
                .message = msg.msg
              }
            }
            if !exists(._SYSTEMD_UNIT) {
              ._SYSTEMD_UNIT = "agent"
            }
          '';
        };

        # http_server_format = {
        #   type = "remap"; # required
        #   inputs = ["http_server"]; # required                         
        #   source = ''
        #     del(.source_type)
        #     del(.path)
        #     msg, err = parse_json(.message)
        #     if err == null {
        #       del(.message)
        #       . = merge!(., msg)
        #     }
        #   '';
        # };
      };

      sinks = {

        loki = {
          endpoint = "http://localhost:3100";
          inputs = [
            "journald_format"
            # "http_server_format" 
          ];
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
}
