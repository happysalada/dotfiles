# Data tools: viewers, wranglers and analysis for CSV/parquet/json and friends.
# Workstation only - bee and hetz have no data to look at, so none of this
# belongs in basic_cli_set.nix, which they also import.
{ pkgs }:
with pkgs;
[
  tabiew # TUI viewer for csv/parquet/json, sql over files
  qsv # fast, maintained CSV wrangling (the xsv successor)
  visidata # `vd`, a terminal spreadsheet over any tabular source
  duckdb # in-process SQL over csv/parquet/json
  csvlens # a lighter TUI CSV viewer
  miller # `mlr`, streaming transforms over delimited/JSON data
]
