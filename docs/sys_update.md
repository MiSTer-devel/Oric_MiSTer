# Updating sys/ from upstream

As of 2026-06-10 (`full_sys_update` branch), `sys/` is **byte-identical to
stock upstream** (`git diff upstream/master -- sys/` is empty). Upstream sys
updates are now ordinary merges: take upstream's side for everything under
`sys/`, rebuild, and run the device test matrix below. No local sys patch
needs to be preserved.

## Procedure for an upstream sys update

1. Do the merge in a throwaway worktree
   (`git worktree add ../Oric_MiSTer-update -b upstream-update master`).
2. Resolve any `sys/` conflicts by taking upstream's side verbatim; after
   resolving, `git diff upstream/master -- sys/` must be empty.
3. Syntax-check (`quartus_map` A&S only, ~1 min — see `build.md`), then full
   `./tools/oric-build`.
4. Device-test the hps_io-dependent paths:
   - TAP load and SNA load via OSD or MGL (these use the fio/ioctl
     download path);
   - Pravetz DSK mount and DOS boot (`_Games/_Oric/dos_8d_dsk.mgl`), and the
     NIB variant (`dos_8d_nib.mgl`) — sd block path;
   - savestate save/restore hotkeys F1–F8 (DDR path).

## History: the fio_block fork (resolved)

From 2026-05-26 to 2026-06-10 this fork carried a single local patch in
`sys/hps_io.sv`: commit `9b5be91` reverted the `fio_block` process to the
pre-May-2026 "old style" (immediate `ioctl_download` assert, shadow `addr`
register) because Pravetz 8D disk loading had stopped working after the
2026-05-11 upstream sys update (`edb2ca2`) introduced the "new style"
(deferred assert via `req_io`, pre-increment with `skip_add`). The patch
even travelled upstream inside PR #16 (`ff64e25`) before Sorgelig's
2026-06-03 sys update (`b7c4d04`) re-applied the new style.

The 2026-06-10 investigation (branch `full_sys_update`) retired the patch:

- **Why the May breakage doesn't apply anymore.** Main_MiSTer serves disk
  mounts (`<file type="s">`, OSD S-slot mounts) entirely over the UIO /
  sd-block path (`user_io_file_mount`, `UIO_SECTOR_RD`); the DSK→NIB
  conversion happens per-sector in Main (`support/a2/dsk2nib_lib.cpp`).
  Savestates ("SS" config string) use direct DDR mapping in Main
  (`process_ss()` / `shmem_map`). Neither touches fio/ioctl. The only
  fio/ioctl consumers in today's core are the TAP (index 1), SNA (index 4)
  and alternate-BIOS (index 2) downloads in `Oric.sv`. The May failure
  ("mount disk, `CALL 800`, nothing happens") was observed while the
  Pravetz disk content still flowed through the ioctl *launcher* path of
  the bring-up era — an architecture that no longer exists; current disk
  loading never sees the `fio_block`.
- **Verification with stock sys** (build `Oric_20260610_163752_021dfd4`):
  TAP load, SNA load, Pravetz DSK and NIB mount + DOS boot, and F1–F8
  savestates all pass on device with upstream's new-style `fio_block`.

If a future sys update ever breaks a file-load path again, the fix belongs
on the **core side** (the `ioctl_*` consumers in `Oric.sv`:
`tape_end`/`snap_end` latching, the `*_loaded` falling-edge flags, the
filecache write window, `rtl/snap_loader.v`) — do not fork `sys/` again.
For reference, the behavioral differences between the two `fio_block`
styles are: assert timing of `ioctl_download`/`ioctl_upload` (deferred to
the end of the header packet in the new style), address bookkeeping
(pre-increment with `skip_add` vs shadow `addr` register — final
`ioctl_addr` after a download is the byte count in both), and the upload
priming `ioctl_rd` pulse (old style only).
