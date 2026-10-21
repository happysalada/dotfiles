# Local backups: rustic onto the second drive

Status, 2026-10-23: **implemented, built, tested in scratch; not activated.**
Nothing was staged, committed, deployed, deleted or backed up for real. The
btrbk job and its snapshot are untouched. Continue at [Cutover](#cutover).

## What it does

| | |
| --- | --- |
| Tool | rustic (patched build shared with the offsite job, `modules/rustic-package.nix`). Same repository format as restic. |
| Repository | `/mnt/backup/rustic/strix`, cache `/mnt/backup/rustic/cache`. Both on the second disk, never on `/`. |
| Password | agenix `secrets/rustic-local.password.age`, read at `/run/agenix/rustic-local-password`. Keep a copy off this machine: losing it loses the backups. |
| Datasets | `/home` and `/var/lib/fundies`, two rustic snapshots per run (tags `home`, `fundies`). |
| Source view | Temporary read-only Btrfs snapshots, deleted at the end of every run. Nothing persists on `/` between runs. |
| Schedule | backup daily 03:30, forget+prune Sundays 07:00, check Wednesdays 07:00. All `Persistent`, idle CPU and I/O class. |
| Failure | each unit's `OnFailure` raises a critical toast (`rustic-local-failed@`). |

Files: `modules/rustic-local.nix` (units, config), `modules/rustic-local.nu`
(logic), `modules/rustic-package.nix`, `homes/programs/disk-space-guard.{nix,nu}`,
`secrets/rustic-local.password.age` + its rule, one import in
`machines/strix/default.nix`.

## How a run works

1. **Disk gate.** `findmnt` must show `/mnt/backup` mounted, `btrfs`, with
   filesystem UUID `8b025d72-8310-4adc-b1ed-bd592b9089e4`, and the repository
   must already exist. Otherwise the run stops before touching anything.
   Nothing but `init` creates the repository, and `init` runs the same gate.
   `RequiresMountsFor=/mnt/backup` makes systemd refuse the unit too.
2. **Sweep.** Directories `/.rustic-snapshots/rustic-<timestamp>` are leftovers
   of a killed run and are deleted (subvolumes only, one level down, never
   `rm -r`). btrbk's `/.snapshots` is never looked at. Runs are serialised by
   `flock`, so a running backup excludes a sweep; `ExecStopPost` sweeps again,
   which covers `kill -9` and OOM.
3. **Nested-subvolume audit.** Snapshots do not recurse. Any subvolume listed
   under `home/` or `var/lib/fundies/` aborts the run, because it would be
   backed up as an empty directory. None is expected: `fundies-target` is a
   mount of a top-level subvolume, not nested.
4. **Snapshots.** `/home` is its own subvolume. `/var/lib/fundies` is a plain
   directory inside the top-level subvolume, so the top-level subvolume (`/`) is
   snapshotted and only `var/lib/fundies` is read from it. `/` is snapshotted
   first so it does not carry the other snapshot as a nested subvolume.
5. **Backup.** `rustic backup --as-path <original path> .` run from inside
   each snapshot: stored paths are `/home` and `/var/lib/fundies` and stay the
   same each run, so rustic finds the parent snapshot and only reads changes.
   Globs anchor to the working directory, which is why it runs inside the
   snapshot. `--one-file-system --no-scan --skip-if-unchanged`.
6. **Remove** the snapshots, success or failure. A failed dataset does not stop
   the other; the unit still fails at the end.

### Database consistency

The snapshot is atomic across the whole subvolume, so each SQLite database
(`store/ledger.sqlite`, `openfigi`, `openpermid`, `corpus/corpus.sqlite`,
`filings/filing_text.sqlite`) is captured together with its `-wal` and `-shm`
as one instant. Restoring it behaves like recovery after a power cut. The
sidecars are never excluded. Tested with a database holding uncheckpointed
WAL rows: restored byte-identical, `integrity_check` ok, all rows present.

There is no application coordination beyond that. If a Fundies writer
(`fundies-archiver`, `-reconcile`, `-publish`, `esef-release`) is running when
the snapshot is taken, the rustic snapshot is tagged `writers-active`, else
`writers-idle`, so a restore can prefer a quiet one. Stopping the writers first
is optional; it is not required for a restorable backup.

## What is and is not backed up

Backed up in `/var/lib/fundies`: everything, including `store/` (blobs, ledgers,
corpus, openfigi/openpermid), `releases/` (receipts, decoded inputs pinned by
them), `mapped/`, `search/`, `migration-backup/`, `archiver/`, `filings/`, the
rest. Measured at 732 GiB apparent.

Excluded, and why:

| Pattern | Why |
| --- | --- |
| `/home/yt/dev/fundies/{data,crates/store/data,crates/archiver/data}` | Obsolete runtime roots, reflink copies of `/var/lib/fundies` (735 GiB referenced). Backing them up reads that twice. They stay in the btrbk backup until it is retired. If cleanup is delayed and you want them protected, delete those six lines in `rustic-local.nix`. |
| `/var/lib/fundies/publication-work/*/candidate` | Private candidate copied into serving objects on publication. The small proof files beside it are kept. |
| `**/.cache`, `Trash`, `node_modules`, `target`, `.venv`, `__pycache__`, `.direnv` under `/home` | Rebuildable. Same list as the offsite job. `target/` is also a separate subvolume. |

No backup repositories exist under `/home` or `/var/lib/fundies` (searched); the
new repository lives on the other disk.

Not decided here: `mapped/` (94 GiB), the unpinned `esef-2023-2024*` trees and
old `releases/*` are possibly intermediate, but the migration notes say pruning
those needs a reference audit, so they are kept.

## Retention and sizing

Defaults: **7 daily, 4 weekly, 6 monthly**, prune once the unused share exceeds 5%.

Measured: a 10.8 GiB sample (blob shards 00 and 01, the 4.9 GB ledger, corpus,
receipts) became 5.1 GiB added (raw 10.3), 47%. The data is mostly
content-addressed and append-only, so a later snapshot adds only new blobs plus
whatever the ledgers rewrite.

Estimated (not measured): 732 GiB of Fundies at that ratio is about 350 GiB, and
`/home` outside the excluded trees about 60 GiB, so the first repository is
roughly **350 to 450 GiB**. Worst case each retained snapshot adds one full
ledger rewrite (about 2.3 GiB compressed), so 17 snapshots add under 40 GiB, and
5% slack is about 20 GiB. Against 1.26 TB free that leaves more than 700 GB
before the old btrbk backup is retired, and about 1.3 TB after. That is why the
policy is moderate rather than lean: the disk is not the constraint, a ledger
that gets corrupted unnoticed is, and half a year of months covers that.

## Disk monitoring

`disk-space-guard` (hourly user timer) checks each disk on its own with `df`
availability, not `du`:

| Disk | warns below | critical below |
| --- | --- | --- |
| primary `/` | 20% free | 15% free |
| backup `/mnt/backup` | 15% free | 8% free |

An unmounted backup disk is critical (df would otherwise answer for `/`).
One toast per disk per worse level or 2-point drop. Today: primary 26% free,
backup 61%. Tested with a stub `notify-send`.

## Performance

Sample, run through Pueue (task 12852) at idle priority while the receipt
verification (12846) was still running; rustic 0.11.4, repository on tmpfs.

| | Initial | Unchanged re-run |
| --- | --- | --- |
| Data | 54,767 files, 10.8 GiB | same |
| Wall | 15.7 s | 0.74 s |
| CPU (user + sys) | 92.7 s, 590% | 1.5 s |
| Peak RSS | 468 MB | 142 MB |
| Added to repo | 5.1 GiB | 0 B |
| Restore of the 4.6 GiB ledger | 6.3 s, RSS 2.4 GB | |

Cold metadata walk of the whole tree (task 12853, `find`, idle priority):
`/var/lib/fundies` is **12,070,589 files**, walked in 1 min 49 s. `/home/yt`
outside the excluded trees is 1,006,454 files, walked in 2 min 2 s. So an
unchanged run is bounded below by about 4 minutes of metadata reads, plus
rustic's tree comparison, which is unmeasured at that scale (0.74 s for 55k
files, about 160 s if it scaled linearly: an extrapolation, not a result).

Limits of the sample, which matter:

- **Warm cache.** The verification had just read these files, so reads came
  from page cache. The 15.7 s is an upper bound on speed, not a prediction.
- **tmpfs target.** Write speed and Btrfs zstd behaviour on the second disk are
  not measured. The secondary is root-writable only, so no repository could be
  created there from this session.
- **Small file count.** 54,767 files against 13 million, about 240 times fewer. Index and tree memory
  scale with file count, so peak RSS for the full tree is unknown; budget
  several GB and check `systemctl status rustic-local-backup` after the first
  run.
- **First real run is unmeasured.** Expect hours, bounded by the secondary's
  write speed and the 700+ GiB read.

## Not tested, and why

Root is required and `sudo` needs a password, so these ran as stubs or not at
all. `rustic-local-preflight` exercises most of them without writing data.

- Real `btrfs subvolume delete` (the test used an emulation; snapshot creation,
  inode checks and snapshotting a subvolume into itself were real). Unprivileged
  delete is refused by this filesystem, root is not.
- The parse of `btrfs subvolume list` output (tested on canned text in the
  documented `ID n gen n top level n path P` form).
- Snapshotting `/` for real into `/.rustic-snapshots`.
- The systemd units, `flock` chain, `ExecStopPost` and toast as installed.

## Cutover

Do these in order; each step is reversible until step 8. Writers are paused and
the receipt verification may still be running; the backup only reads, but it
will compete for I/O, so prefer starting after `pueue status` shows it done.

1. **Review the working tree.** Activation applies *all* uncommitted changes
   (clamav, zed, fundies modules), not just this one.
   ```sh
   git -C ~/dotfiles status
   git -C ~/dotfiles diff -- modules/rustic-local.nix modules/rustic-local.nu modules/rustic-package.nix modules/rustic.nix homes/programs/disk-space-guard.nix homes/programs/disk-space-guard.nu machines/strix/default.nix secrets/agenix-rules.nix
   git -C ~/dotfiles add -N secrets/rustic-local.password.age   # then stage and commit as you see fit
   ```
   The secret is a new untracked file; keep a copy of its plaintext offsite:
   `age -d -i ~/.ssh/id_ed25519 ~/dotfiles/secrets/rustic-local.password.age`.
2. **Build, then activate** (nothing runs yet: no repository exists, and a
   timer with no history does not fire at activation).
   ```sh
   nix build --no-link "path:$HOME/dotfiles#nixosConfigurations.strix.config.system.build.toplevel"
   sudo nixos-rebuild switch --flake ~/dotfiles#strix
   systemctl list-timers 'rustic-local-*'
   ```
3. **Create the repository** (checks the disk identity first):
   ```sh
   sudo systemctl start rustic-local-init
   journalctl -u rustic-local-init -n 20 --no-pager
   ```
4. **Preflight.** Snapshots, audit and repository open; no data moved; the
   snapshots are removed afterwards.
   ```sh
   sudo systemctl start rustic-local-preflight
   journalctl -u rustic-local-preflight -n 30 --no-pager
   sudo ls -A /.rustic-snapshots        # must be empty
   ```
5. **First full backup**, through Pueue so it survives the session (`sudo -v`
   first; the oneshot blocks until done):
   ```sh
   pueue add -l rustic-local-first -p -- sudo systemctl start rustic-local-backup
   journalctl -fu rustic-local-backup
   ```
6. **Integrity.** Structure plus a 5% read-back, then a full read-back once:
   ```sh
   sudo systemctl start rustic-local-check
   sudo env RUSTIC_REPOSITORY=/mnt/backup/rustic/strix RUSTIC_PASSWORD_FILE=/run/agenix/rustic-local-password RUSTIC_CACHE_DIR=/mnt/backup/rustic/cache rustic check --read-data
   ```
   Also confirm a second, incremental run is fast and adds little
   (`sudo systemctl start rustic-local-backup`, then the snapshot table below).
7. **Restore test**, to the *second* disk, never `/`:
   ```sh
   export RUSTIC_REPOSITORY=/mnt/backup/rustic/strix RUSTIC_PASSWORD_FILE=/run/agenix/rustic-local-password RUSTIC_CACHE_DIR=/mnt/backup/rustic/cache
   sudo -E rustic snapshots
   sudo -E rustic restore latest:var/lib/fundies/store /mnt/backup/restore-test --glob 'ledger.sqlite*'
   sudo -E rustic restore latest:var/lib/fundies/releases /mnt/backup/restore-test/releases --glob 'receipts/2026-10-23.json'
   sqlite3 /mnt/backup/restore-test/ledger.sqlite 'PRAGMA integrity_check;'
   sha256sum /mnt/backup/restore-test/releases/receipts/2026-10-23.json   # dbe962ad86d95d97ca7c76df846908f6b1801b343abacd55d6a6ed152eea047c
   sudo rm -r /mnt/backup/restore-test
   ```
   (Compare the ledger to the source only while Fundies writers are stopped.)
8. **Gate.** Proceed to retirement only when: both datasets saved, `check
   --read-data` clean, a restore test passed, and at least two nightly runs
   succeeded. The old backup stays recoverable until then:
   `/.snapshots/home.20261019T0528` and `/mnt/backup/home/home.20261019T0528`.

## Retire btrbk (after step 8; not executed)

Measure before and after, so the saving is a number rather than an estimate:
```sh
df -B1 --output=avail / /mnt/backup
sudo btrfs filesystem usage -b /
```
1. Remove the `services.btrbk.instances.home` block and the
   `systemd.tmpfiles.rules = [ "d /.snapshots ..." ]` line from
   `machines/strix/default.nix`; **keep** the `fileSystems."/home/yt/dev/fundies/target"`
   mount. Rebuild and switch. This stops the Saturday run, which would
   otherwise replace the snapshot and backup.
2. Delete the old snapshot and received backup:
   ```sh
   sudo btrfs subvolume delete /.snapshots/home.20261019T0528
   sudo btrfs subvolume delete /mnt/backup/home/home.20261019T0528
   sudo btrfs subvolume sync / /mnt/backup
   df -B1 --output=avail / /mnt/backup
   ```
   Space is reclaimed asynchronously; `subvolume sync` waits for it.

Reclaimable space:

| | Measured | Estimated |
| --- | --- | --- |
| Local snapshot, referenced | 644.17 GiB | |
| Local snapshot, exclusive file extents | 155.39 GiB (extent audit, 13:39 EDT) | frees roughly this on `/`, not exactly: metadata, encoded extents and extents shared only within the snapshot shift it |
| Old backup on the second disk | 572 GB used on the disk (`df`) | frees about that, minus anything else stored there |
| Primary headroom after retirement | 554 GB free now | roughly 700 GB (about 35%) |

Ongoing after cutover: no persistent snapshot on `/`; the only primary-side cost
is the transient copy-on-write while a run is open.

## Rollback

Disable by removing the `../../modules/rustic-local.nix` import and switching.
The repository is plain files under `/mnt/backup/rustic/`; deleting it is
`sudo rm -r /mnt/backup/rustic` and nothing else depends on it.

## Gaps for later

- The offsite job (`modules/rustic.nix`, B2) backs up `/home` only, so
  `/var/lib/fundies` has no offsite copy. Adding it is a cost decision (about
  350 GiB stored).
- `/var/lib/fundies` could be its own subvolume, which would shrink the
  snapshot to just that tree. It means moving 700+ GiB (reflink, same disk) and
  is not needed for this to work.
- `qdrant` (`filings/qdrant`, 2.3 GB) and Meilisearch are rebuildable indexes;
  Qdrant's directory is captured crash-consistently, Meilisearch's lives outside
  the protected paths.
- `/etc` and `/root/luks-backup.key` are not backed up; the key unlocks the
  backup disk and is itself on the encrypted root.
