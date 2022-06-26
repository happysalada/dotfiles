{ config, lib, pkgs, ... }:

{
  services.mimir = {
    enable = true;
    configuration = {
      multitenancy_enabled = false;

      blocks_storage = {
        backend = "filesystem";
      };

      compactor = {
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
        ring = {
          instance_addr = "127.0.0.1";
        };
      };

      ruler_storage = {
        backend = "local";
        local = {
          directory = "/var/lib/mimir";
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
      
      memberlist = {
        bind_addr = ["127.0.0.1"];
      };
    };
  };
}
