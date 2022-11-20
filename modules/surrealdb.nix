{ config, lib, pkgs, ... }:

{
  services.surrealdb = {
    enable = true;
  };
}
