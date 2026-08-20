# dotfiles

NixOS configurations, built as a flake.

## Machines

| name    | what it is                                    | how it's deployed          |
| ------- | --------------------------------------------- | -------------------------- |
| `strix` | ASUS ROG Strix G18 (G834JY) workstation/laptop | locally, `nixos-rebuild`   |
| `bee`   | home server                                   | `nixinate`                 |
| `hetz`  | Hetzner dedicated                             | `nixinate`                 |

## Rebuilding strix

```sh
sudo nixos-rebuild switch --flake ~/dotfiles#strix
```

Test without making it the boot default:

```sh
sudo nixos-rebuild test --flake ~/dotfiles#strix
```

Roll back: pick the previous generation in the systemd-boot menu, or

```sh
sudo nixos-rebuild switch --rollback
```

Bump inputs:

```sh
nix flake update && sudo nixos-rebuild switch --flake ~/dotfiles#strix
```

## Deploying the servers

```sh
nix run .#apps.x86_64-linux.bee
nix run .#apps.x86_64-linux.hetz
```

## Layout

- `machines/<name>/` — per-machine NixOS config + hardware scan
- `homes/common.nix` — the `programs.*` set shared by every machine
- `homes/programs/` — one file per program, imported by `common.nix`
- `packages/` — package lists, imported into `home.packages`
- `modules/` — service modules used by the servers
- `secrets/` — agenix-encrypted secrets

## strix specifics

- **GPU**: NVIDIA PRIME offload. The Intel iGPU drives the display; run
  `nvidia-offload <cmd>` to put something on the 4090. There's also a
  `battery-saver` boot entry that disables the dGPU outright.
- **RGB**: all Aura zones are forced off at boot and after resume by the
  `aura-off` systemd unit.
- **Battery**: charging stops at 80% (`hardware.asus.battery.chargeUpto`).
  `charge-upto 100` lifts it until reboot; `asusctl battery oneshot` does a
  single full charge.
- **Terminal**: ghostty, bound to `Super+T` via a GNOME custom keybinding.
