# Prefect's server on loopback: the UI, run history and logs for the flows this
# machine runs. `modules/prefect.nix` is bee's - it publishes the UI through
# Caddy under a public name, which is the one thing a laptop should not do.
#
# No `workerPools`. A worker exists to poll a work pool for deployment runs,
# and the flows here are launched by systemd timers instead - `Persistent`
# catches up a run the machine slept through, which is most Monday mornings,
# and is not something prefect's own scheduler can do while powered off.
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
