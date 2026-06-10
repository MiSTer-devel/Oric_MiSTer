# Tools summary

This directory contains small command-line helpers for building the MiSTer core
and inspecting or manipulating Oric tape/snapshot files. Run paths below from
the repository root unless noted.

## Build tool

- `oric-build` compiles `Oric.qpf` inside the `raetro/quartus:mister` Docker
  image. By default it also deploys the generated `output_files/Oric.rbf` to
  `root@192.168.0.108:/media/fat/_Aoric` for development and refreshes the
  official `/media/fat/_Computer/Oric_YYYYMMDD.rbf` used by MGL launchers.
- Useful options:
  - `--no-deploy` compiles only.
  - `--clean` removes `db`, `incremental_db`, and `output_files` before build.
  - `--no-hdmi` injects `MISTER_DEBUG_NOHDMI=1` for faster development builds.
  - `--snap-debug` injects `SNAP_DEBUG=1` to paint captured snapshot CPU
    registers on the text screen after load.
- The script expects to be run from the repo root and checks for `Oric.qpf`.
  Dev deploys are timestamped with the current date/time and short git SHA,
  then copied to a stable `_Aoric/Oric.rbf` name. The official deploy removes
  previous `_Computer/Oric*.rbf` files and uploads a date-stamped core.

Example:

```sh
./tools/oric-build --no-deploy
./tools/oric-build --clean --no-hdmi
```

## TAP inspection and manipulation

- `tape-inspect.py` prints the structure of an Oric `.tap` file. It handles
  multi-segment tapes, reports sync/header/name/address information, and can
  detokenize BASIC payloads.
- The core clamps TAP uploads at 160 KiB in its shared FPGA file cache.
  Larger files can still be inspected, but the core will not cache bytes
  beyond that limit.
- Output modes:
  - `--short` is the default and shows a 10-byte preview per segment.
  - `--basic` detokenizes BASIC segments and previews machine-code segments.
  - `--full` detokenizes BASIC and fully dumps machine-code payloads as hex and
    decimal rows.

Example:

```sh
python3 tools/tape-inspect.py --basic games/Oric/tap/example.tap
```

- `splitter.py` splits a multi-segment `.tap` into one self-contained file per
  segment, named `<stem>_0.tap`, `<stem>_1.tap`, and so on next to the input.
  Inter-segment padding and trailing junk are dropped. It refuses to overwrite
  existing outputs unless `--force` is used.

Example:

```sh
python3 tools/splitter.py games/Oric/tap/game.tap
python3 tools/splitter.py --force games/Oric/tap/game.tap
```

- `merger.py` concatenates one or more `.tap` files into a single multi-segment
  tape in command-line order. With `--replace-cload`, it walks BASIC segments
  and rewrites tokenized `CLOAD` bytes to `PRINT` outside string literals before
  merging.

Example:

```sh
python3 tools/merger.py -o games/Oric/tap/combined.tap games/Oric/tap/part1.tap games/Oric/tap/part2.tap
python3 tools/merger.py -o games/Oric/tap/combined.tap --replace-cload games/Oric/tap/loader.tap games/Oric/tap/payload.tap
```

## Snapshot inspection

- `sna-inspect.py` walks an Oricutron `.sna` typed-block container and decodes
  known blocks: `OSN`, `DATA`, `TAP`, `PCH`, `CPU`, `AY`, and `VIA`.
- It reports block offsets and payload sizes, validates expected fixed block
  sizes where known, decodes big-endian fields, previews unknown blocks, and
  identifies `DATA` payloads as RAM or tape buffer based on the preceding block.
- This is the matching diagnostic tool for the snapshot format documented in
  `docs/sna_support.md` and `docs/oricutron_snapshot_internals.md`.

Example:

```sh
python3 tools/sna-inspect.py games/Oric/snapshots/example.sna
```

## Savestate conversion

- `ss-convert.py` converts between MiSTer savestates (`.ss`, produced by the
  F1-F4 hotkeys, stored in `/media/fat/savestates/Oric/`) and Oricutron
  `.sna` snapshots. A `.ss` file is a `.sna` container prefixed with the
  8-byte MiSTer Main header (u32 LE change counter + u32 LE payload size in
  dwords).
- `to-sna` strips the header so the snapshot loads in desktop Oricutron;
  `to-ss` pads the container to a dword boundary with a `PAD` block and
  prepends the header so an Oricutron save can be restored on the MiSTer
  with F5-F8; `inspect` decodes the header and runs `sna-inspect.py` on the
  embedded payload.

Example:

```sh
python3 tools/ss-convert.py to-sna "savestates/Oric/game_1.ss" game.sna
python3 tools/ss-convert.py to-ss game.sna "savestates/Oric/game_1.ss"
python3 tools/ss-convert.py inspect "savestates/Oric/game_1.ss"
```

## Notes

- The Python tools use only the standard library.
- All TAP parsing assumes Oric framing with repeated `0x16` sync bytes followed
  by `0x24`, a 9-byte header, a NUL-terminated filename, and a payload length
  derived from the start/end addresses.
- Snapshot parsing assumes Oricutron's 8-byte block envelope and big-endian
  numeric fields.
