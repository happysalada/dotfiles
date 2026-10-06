{ ... }:
{
  enable = true;

  # The binary also comes from packages/basic_cli_set.nix, which the machines
  # without a home-manager profile still need. Same derivation, so the overlap
  # costs nothing; this module is here for the config alone.
  #
  # Upstream's "all" fills the CPU widget with a row per core; the average is the
  # number this machine is watched for. Only deviations are declared - the rest is
  # in upstream's sample_configs/default_config.toml.
  settings.cpu.default = "average";
}
