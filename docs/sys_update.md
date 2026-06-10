# Updating sys/ from upstream (and the path to a stock sys)

This note documents the one place where this fork diverges from the stock
MiSTer sys framework, why that divergence exists, how to perform an upstream
sys update safely today, and what has to happen before we can take upstream
sys verbatim with no local patch.

## Current divergence: one block in `sys/hps_io.sv`

As of the 2026-06-10 upstream merge (`233b501`, upstream release 20260603),
`git diff upstream/master -- sys/` shows exactly one delta: the `fio_block`
process in `sys/hps_io.sv` (~30 lines). Everything else in `sys/` is stock.

Upstream's "new-style" `fio_block` (introduced in the 2026-05-11 sys update
`edb2ca2`, re-applied in the 2026-06-03 sys update `b7c4d04`):

- latches the requested direction into a `req_io` register during the
  `FIO_FILE_TX` header packet, and only asserts `ioctl_download` /
  `ioctl_upload` when the header packet's chip-select (`fp_enable`) drops;
- pre-increments `ioctl_addr` on every `FIO_FILE_TX_DAT` strobe, using a
  `skip_add` flag to keep the first byte at the header-supplied address;
- for uploads, does **not** fire the priming `ioctl_rd` pulse during the
  header packet.

Our "old-style" block (restored by `9b5be91`, carried upstream inside PR #16
/ `ff64e25`):

- asserts `ioctl_download` / `ioctl_upload` (and the priming `ioctl_rd` for
  uploads) immediately, mid-header-packet;
- keeps a shadow `addr` register, drives `ioctl_addr` together with each
  `ioctl_wr`, and restores the final byte count into `ioctl_addr` when the
  transfer closes.

### History

| Date (2026) | Commit | What happened |
|---|---|---|
| May 11 | upstream `edb2ca2` | Sys update brought the new-style `fio_block`. After merging it, Pravetz 8D disk mounts broke. |
| May 26 | local `9b5be91` | Reverted only the `fio_block` to the old style; mounts worked again. |
| May 28 | upstream `ff64e25` (PR #16) | Our Pravetz support, including the old-style `fio_block`, squash-merged upstream. |
| Jun 3 | upstream `b7c4d04` | Sorgelig's sys update re-applied the new-style `fio_block` byte-for-byte (plus unrelated, kept changes: `HPS_BUS` narrowed to `[45:0]`, status responses `'h2B/'h2F/'h39/'h3E` moved to `sys_top.v`, `audio_out.v` → `audio_out.sv` with volume boost, new `sys/emu_ports.vh`). |
| Jun 10 | local `233b501` | Merge kept our old-style block **only by 3-way-merge accident**: upstream had returned that region to the merge-base state, so git silently preferred our side. |

The accident is the trap: a future sys update will modify that region again,
and git may then auto-merge the breaking version in **with no conflict
marker**. Never trust a clean merge of `sys/hps_io.sv`.

## Procedure for every upstream sys update (interim)

1. Do the merge in a throwaway worktree
   (`git worktree add ../Oric_MiSTer-update -b upstream-update master`).
2. After resolving, diff the merged `fio_block` against our reference:
   `git diff 9b5be91 HEAD -- sys/hps_io.sv` — the `fio_block` region must be
   unchanged. If upstream changed *other* parts of `hps_io.sv`, take them.
3. Syntax-check (`quartus_map` A&S only, ~1 min — see `build.md`), then full
   `./tools/oric-build`.
4. Device-test the paths that depend on hps_io transfer behavior:
   - Pravetz DSK mount and DOS boot (`_Games/_Oric/dos_8d_dsk.mgl`), and the
     NIB variant (`dos_8d_nib.mgl`);
   - TAP load, SNA load via OSD;
   - savestate save/restore hotkeys F1–F8 (both directions use the fio
     upload/download machinery via MiSTer Main slots).

## Long-term fix: make the core tolerate stock sys

The goal is `sys/` == upstream, no local patch, so sys updates become
copy-through. The work breaks down as follows.

### 1. Root-cause the mount failure (not yet done)

The failure mechanism was never pinned down — `9b5be91` was an empirical
revert. The puzzle: the Pravetz track loader
(`rtl/apple2_disk/floppy_track.sv`) uses only the **sd block interface**
(`sd_rd`/`sd_ack`/`sd_buff_*`), not ioctl, yet reverting the **fio (ioctl)**
block fixed the mounts. Plausible explanations to confirm or eliminate:

- the MGL mount sequence also performs a fio transfer (e.g. Main's
  DSK→NIB translation feeding the core, or the boot-disk file copy), and the
  new ioctl semantics corrupt that transfer;
- a falling/rising-edge consumer of `ioctl_download` in `Oric.sv`
  (`tape_loaded`/`sna_loaded` latches, `tap_load_pulse`, snap-loader
  trigger, `led_user`) misfires under the deferred-assert timing and leaves
  the core in a state that blocks the mount;
- the failure was specific to the May sys drop and is already moot.

Method: build a branch with stock `hps_io.sv`, reproduce against
`dos_8d_dsk.mgl` / `dos_8d_nib.mgl`, and capture what actually goes wrong
(SignalTap on `ioctl_*` and `sd_*`, or simulate the fio transaction stream
against both block styles and diff the `ioctl_addr`/`ioctl_wr`/
`ioctl_download` traces).

### 2. Adapt the core-side consumers

Once the sensitive consumer is identified, fix it in `rtl/` / `Oric.sv`
rather than in `sys/`. Known consumers of the affected signals, all in
`Oric.sv` unless noted:

- file cache writes for TAP/SNA (`filecache_write_we`,
  `file_download_in_range` — bounds-checks `ioctl_addr`);
- `tape_end` / `snap_end` latched from `file_download_addr` while the
  download is active — sensitive to end-of-transfer `ioctl_addr` semantics;
- `*_loaded` flags and `tap_load_pulse` on the falling edge of
  `ioctl_download` — sensitive to assert/deassert timing;
- alternate BIOS load (`load_alt_bios` path into the `altbios` RAM);
- `rtl/snap_loader.v` (takes `ioctl_download` directly);
- the savestate SAVE upload path (Main reads the snapshot via fio upload;
  the old style fires a priming `ioctl_rd` during the header packet, the new
  style does not — `snap_ss`/file-cache readout must not rely on that pulse).

The cleanest target behavior: make every consumer edge- and
address-tolerant, i.e. depend only on (`ioctl_wr`, `ioctl_addr`,
`ioctl_dout`) tuples and on `ioctl_download` as a level, never on the exact
cycle it asserts or on the final `ioctl_addr` value after deassert.

### 3. Switch to stock sys and verify

1. Replace `sys/hps_io.sv` with the upstream copy
   (`git checkout upstream/master -- sys/hps_io.sv`).
2. Confirm `git diff upstream/master -- sys/` is empty.
3. Full build, then the complete device matrix from the interim procedure
   above (both mount formats, TAP, SNA, alt BIOS if used, F1–F8
   savestates).
4. Retire the `fio_block` check from the merge procedure; sys updates
   become ordinary merges.

If root-causing instead reveals a genuine upstream regression (i.e. stock
new-style `fio_block` is broken for any core using these paths), report it
on the MiSTer Main / template repo with the trace evidence — that converges
to the same end state with no local patch.
