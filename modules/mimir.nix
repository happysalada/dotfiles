{ config, lib, pkgs, ... }:

{
  services.mimir = {
    enable = true;
    configuration = {
      multitenancy_enabled = false;

      blocks_storage = {
        backend = "filesystem";
        bucket_store = {
          sync_dir = "/var/lib/mimir/tsdb-sync";
        };
        filesystem = {
          dir = "/var/lib/mimir/data/tsdb";
        };
        tsdb = {
          dir = "/var/lib/mimir/tsdb";
        };
      };

      compactor = {
        data_dir = "/var/lib/mimir/compactor";
        sharding_ring = {
          instance_addr = "127.0.0.1";
          kvstore = {
            store = "memberlist";
          };
        };
      };

      distributor = {
        ring = {
          instance_addr = "127.0.0.1";
          kvstore = {
            store = "memberlist";
          };
        };
      };


      ingester = {
        ring = {
          instance_addr = "127.0.0.1";
          kvstore = {
            store = "memberlist";
          };
          replication_factor = 1;
        };
      };

      ruler = {
        rule_path = "/var/lib/mimir/data-ruler";
        ring = {
          instance_addr = "127.0.0.1";
        };
      };

      ruler_storage = {
        backend = "local";
        local = {
          directory = "/var/lib/mimir/rules";
        };
      };

      server = {
        http_listen_port = 9009;
        log_level = "warn";
        # loki is listening on 9095 by default
        grpc_listen_port = 9096;
      };

      store_gateway = {
        sharding_ring = {
          replication_factor = 1;
          instance_addr = "127.0.0.1";
        };
      };
      
      activity_tracker = {
        filepath = "/var/lib/mimir/metrics-activity.log";
      };
      
      memberlist = {
        bind_addr = ["127.0.0.1"];
      };
    };
  };
}
