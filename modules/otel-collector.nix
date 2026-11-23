# Local OTel Collector: journald and host metrics into the local GreptimeDB.
# The contrib distribution is required for the journald and hostmetrics
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
        journald = {
          directory = "/var/log/journal";
          start_at = "end";
          storage = "file_storage";
        };

        hostmetrics = {
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
        resourcedetection.detectors = [ "system" ];
      };

      exporters = {
        "otlphttp/logs" = {
          endpoint = "http://127.0.0.1:4000/v1/otlp";
          tls.insecure = true;
        };
        "otlphttp/metrics" = {
          endpoint = "http://127.0.0.1:4000/v1/otlp";
          tls.insecure = true;
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
            receivers = [ "journald" ];
            processors = [ "memory_limiter" "resourcedetection" "batch" ];
            exporters = [ "otlphttp/logs" ];
          };
          metrics = {
            receivers = [ "hostmetrics" ];
            processors = [ "memory_limiter" "resourcedetection" "batch" ];
            exporters = [ "otlphttp/metrics" ];
          };
        };
      };
    };
  };

  systemd.services.opentelemetry-collector.after = [ "greptimedb.service" ];
}
