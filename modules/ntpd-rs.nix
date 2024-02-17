{
  # better ntp
  services.ntpd-rs = {
    enable = true;
    metrics.enable = true;
  };
  services.ntp.enable = false;
}
