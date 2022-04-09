{ config, lib, pkgs, ... }:
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_14;
    # only use to make the initial upload
    # or create extensions
    # authentication = lib.mkForce ''
    #   # Generated file; do not edit!
    #   # TYPE  DATABASE        USER            ADDRESS                 METHOD
    #   local   all             all                                     trust
    #   host    all             all             127.0.0.1/32            ident
    #   host    all             all             ::1/128                 ident
    # '';

    # https://pgtune.leopard.in.ua/#/
    # DB Version: 13
    # OS Type: linux
    # DB Type: web
    # Total Memory (RAM): 32 GB
    # CPUs num: 24
    # Data Storage: ssd
    settings = {
      max_connections = 200;
      shared_buffers = "8GB";
      effective_cache_size = "24GB";
      maintenance_work_mem = "2GB";
      checkpoint_completion_target = 0.7;
      wal_buffers = "16MB";
      default_statistics_target = 100;
      random_page_cost = 1.1;
      effective_io_concurrency = 200;
      work_mem = "10485kB";
      min_wal_size = "1GB";
      max_wal_size = "4GB";
      max_worker_processes = 24;
      max_parallel_workers_per_gather = 4;
      max_parallel_workers = 24;
      max_parallel_maintenance_workers = 4;
    };
  };
}
