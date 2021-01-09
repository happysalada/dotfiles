# This is a slimmed down version of the config that is generated with
# nixos-generate-config. I removed everything that I understood well
# enough to be sure it is not necessary for working on nixos via ssh.

{ config, pkgs, ... }:

{

  # Make it boot on the RP, taken from here: https://nixos.wiki/wiki/NixOS_on_ARM/Raspberry_Pi_4
  boot = {
    loader = {
      grub.enable = false;
      raspberryPi.enable = true;
      raspberryPi.version = 4;
    };
    kernelPackages = pkgs.linuxPackages_rpi4; # Mainline doesn't work yet

    # ttyAMA0 is the serial console broken out to the GPIO
    kernelParams = [
      "8250.nr_uarts=1" # may be required only when using u-boot
      "console=ttyAMA0,115200"
      "console=tty1"
    ];
  };

  users.users = {
    yt = {
      isNormalUser = true;
      extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
      home = "/home/yt";
      description = "Yours truly";
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD4gFMJ1LI8cqrHwS3LliffgYP61ix3Wr1YLqFty1K8DGnDVlYvLxiPZFQsfLvQ49hzVEpvy1wftBuA+Wo4XE8RSeSLrYn1+EAfQ/6OWy3/ZlsopoKRZl86YuXWMzPhFRKMI8CTe15qOCAxSJW24pNsg7j02dklfdEjt+6b3NmeHyvqoovfnYjZ6WOmtrxgG6JJwnONOiRlus1nvCYd3xLo2WJgqSw5dif9l4Tm4SRsePQuNGMxidsmI/nAbtp+MQFoD1tjXyv2AbbsgQdRvbE+ZzBXJhFslvu3mjkRPKvmGdaxJp4HMDuJ5ct9jOFeSBFsviLyhY7oqRh5JJMi8ndB raphael.megzari@gmail.com"
      ];
    };
  };

  fileSystems = {
    "/boot" = {
      device = "/dev/disk/by-label/NIXOS_BOOT";
      fsType = "vfat";
    };
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  };

  services = {
    # Enable the OpenSSH daemon.
    openssh.enable = true;

    avahi = {
      enable = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };
  };

  # packages to install
  environment.systemPackages = with pkgs;
    [
      vim # doesn't hurt to have an editor on remote.
    ];

  # Niceties
  programs.bash.enableCompletion = true;
  environment.variables.EDITOR = "vim";
  time.timeZone = "UTC";

  # NTP clock synchronization
  services.timesyncd.enable = true;

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking = {
    useDHCP = false;
    interfaces.eth0.useDHCP = true;
    interfaces.wlan0.useDHCP = true;
    hostName = "nixos";
  };
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.03"; # Did you read the comment?

}
