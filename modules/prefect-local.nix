# Prefect's server on loopback: UI, run history and logs for this machine's
# flows. (modules/prefect.nix is bee's - it publishes the UI through Caddy.)
#
# No `workerPools`: workers poll a work pool for deployment runs, but the flows
# here are launched by systemd timers instead, whose `Persistent` catches up a
# run the machine slept through - which prefect's own scheduler cannot do while
# powered off.
{
  services.prefect = {
    enable = true;
    database = "sqlite";

    # Not optional despite defaulting to null: the module interpolates it
    # unconditionally, so leaving it unset is an eval error. Fixed upstream to
    # default to the bind address; this line can go once that lands here.
    baseUrl = "http://127.0.0.1:4200";
  };
}
