# Local OTel Collector: journald, host metrics, and the Fundies services' own OTLP into
# GreptimeDB. The contrib distribution is required for the journald and host_metrics
# receivers; the core collector does not ship them.
{ pkgs, ... }:
{
  services.opentelemetry-collector = {
    enable = true;
    package = pkgs.callPackage ../packages/otelcol-contrib.nix { };
    # The file_storage directory only exists at runtime (StateDirectory); point
    # validation at /tmp instead of disabling it.
    validateConfigOverrides = [ "extensions::file_storage::directory=/tmp" ];
    settings = {
      extensions.file_storage.directory = "/var/lib/opentelemetry-collector";

      receivers = {
        # The backend and the rolling pipeline push all three signals here.
        otlp.protocols = {
          grpc.endpoint = "127.0.0.1:4317";
          http.endpoint = "127.0.0.1:4318";
        };

        journald = {
          directory = "/var/log/journal";
          start_at = "end";
          storage = "file_storage";
        };

        host_metrics = {
          collection_interval = "30s";
          root_path = "/";
          scrapers = {
            cpu = { };
            disk = { };
            filesystem = { };
            load = { };
            memory = { };
            network = { };
            paging = { };
            processes = { };
            system = { };
          };
        };
      };

      processors = {
        memory_limiter = {
          check_interval = "1s";
          limit_percentage = 75;
          spike_limit_percentage = 15;
        };
        batch = { };
        resource_detection.detectors = [ "system" ];
        # The two service instances and the pipeline export their own stderr logs now, so the
        # journald copy would duplicate them. This collector version keeps the raw journal entry
        # in the body, so match the unit there. `fundies-server.service` is the rollout script
        # and still has no OTLP path, so it is left alone.
        "filter/drop_otel_units" = {
          error_mode = "ignore";
          logs.log_record = [
            ''IsMatch(body, "\"_SYSTEMD_UNIT\":\"fundies-server@a.service\"") or IsMatch(body, "\"_SYSTEMD_UNIT\":\"fundies-server@b.service\"") or IsMatch(body, "\"_SYSTEMD_UNIT\":\"fundies-pipeline.service\"")''
          ];
        };
      };

      exporters = {
        "otlp_http/logs" = {
          endpoint = "http://127.0.0.1:4000/v1/otlp";
          tls.insecure = true;
        };
        "otlp_http/metrics" = {
          endpoint = "http://127.0.0.1:4000/v1/otlp";
          tls.insecure = true;
        };
        # GreptimeDB requires one of its trace pipelines, unlike logs and metrics.
        "otlp_http/traces" = {
          endpoint = "http://127.0.0.1:4000/v1/otlp";
          tls.insecure = true;
          headers = { "X-Greptime-Pipeline-Name" = "greptime_trace_v1"; };
        };
      };

      service = {
        extensions = [ "file_storage" ];
        # The collector's default internal Prometheus telemetry binds 127.0.0.1:8888, which the
        # OpenPanel dashboard already owns; the collector exits before its pipelines start. The
        # collector's own metrics are not shipped anywhere here, so no reader.
        telemetry.metrics = {
          level = "none";
          readers = [ ];
        };
        pipelines = {
          logs = {
            receivers = [ "otlp" "journald" ];
            processors = [ "filter/drop_otel_units" "memory_limiter" "resource_detection" "batch" ];
            exporters = [ "otlp_http/logs" ];
          };
          metrics = {
            receivers = [ "otlp" "host_metrics" ];
            processors = [ "memory_limiter" "resource_detection" "batch" ];
            exporters = [ "otlp_http/metrics" ];
          };
          traces = {
            receivers = [ "otlp" ];
            processors = [ "memory_limiter" "resource_detection" "batch" ];
            exporters = [ "otlp_http/traces" ];
          };
        };
      };
    };
  };

  systemd.services.opentelemetry-collector.after = [ "greptimedb.service" ];
}
