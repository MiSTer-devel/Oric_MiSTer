# Documentation summary

This directory contains both project workflow notes and technical references for
the Oric Atmos MiSTer core. The most active implementation topics are fast tape
loading, live ROM patching, Oricutron-compatible snapshots, and runtime
communication between the emulated 6502 and the FPGA core.

## Start here

- `build.md` explains how to build the core with `tools/oric-build`, including
  Docker/Quartus prerequisites, compile-only and deploy modes, clean builds,
  debug macros, release artifact naming, and common build/deploy failures.
- `sys_update.md` documents the single fork delta in `sys/hps_io.sv` (the
  `fio_block` Pravetz mount-timing patch), the safe procedure for merging
  upstream sys updates, and the long-term plan for running a fully stock sys.
- `tape_loading.md` is the short operational guide for tape loading. It
  explains Tape Load Ultra/Fast/Off, expected load behavior, and the menu
  steps for switching modes.
- `sna_support.md` is the main reference for `.sna` snapshot support in this
  core. It documents the currently working LOAD path, the Oricutron block
  format, field-level mapping into RTL state, ignored blocks, unfinished SAVE
  support, and verification history.

## Core implementation references

- `oric_to_core_comm.md` describes runtime communication patterns between the
  6502 and the FPGA core. It covers bus-snooped write mailboxes, halting the CPU
  to access RAM through the spram mux, read-side ROM overrides, and the current
  `$C000` user LED / Ultra tape trigger mailbox.
- `live_rom_patching.md` explains the read-side ROM patch mechanism used by
  the tape loaders. It documents why live patching is used, how
  `rtl/cload_patch_rom.v` and the `oricatmos.vhd` read mux work, how ROM-space
  addresses map to 14-bit offsets, and how to add new synth-time patches.
- `oricutron_snapshot_internals.md` summarizes Oricutron's own snapshot
  implementation from `snapshot.c`. It is the producer/consumer format
  reference for block IDs, big-endian fields, save order, load order, optional
  blocks, and how Oricutron attaches `DATA` chunks.
- `pravetz_8d_fdc.md` documents the current Pravetz 8D FDC implementation:
  Apple II Disk II softswitches at `$0310-$031F`, BANK0/BANK1 controller ROM
  mapping at `$0320-$03FF`, `$0380-$0383` bank/shadow latches, `.nib` image
  handling, Pravetz `.dsk`/`.do` conversion requirements, and MiSTer
  validation notes.

## Oric reference material

- `oric_memory_map.md` is the consolidated memory map: pages 0..4
  address-by-address (BASIC pointers, OS variables, IRQ/NMI vectors),
  the full page-3 I/O map (VIA 6522 register layout, AY-3-8912 access
  via the VIA, Microdisc / Jasmin / Pravetz / ACIA / RTC / lightpen
  windows), what `CALL #320` actually does on each variant, and a
  hardware overview of how the 6502, ULA, VIA, PSG, keyboard, and
  cassette interact.
- `Oric Rom.md` is a converted Atmos 1.1b ROM disassembly with anchors and
  cross-references. It is the searchable source for BASIC routines, tape
  routines such as CLOAD/CSAVE, keyboard, graphics, sound, reset, IRQ, and ROM
  entry points used by patches.
- `Oric Rom.html` is the HTML companion for the same ROM disassembly.
- `manual_atmos.md` is a text conversion of the Oric Atmos manual. It covers
  setup, BASIC programming, tape usage, graphics, sound, machine code,
  input/output, memory maps, ROM routines, 6502 opcodes, and expansion-port
  details.

## Current project state captured by the docs

- Tape Load = Fast is the default and preferred tape path. It leaves the ROM's
  tape-load flow in charge while replacing cassette byte acquisition with a TAP
  byte feeder and byte-level TAP leader alignment at patched SYNCTAPE.
- Tape Load = Ultra patches the ROM around CLOAD, snoops a write to `$C000`,
  then lets `tap_segment_loader.v` copy the next TAP segment from `tapecache`
  into RAM and update BASIC state where needed.
- Tape Load = Fast patches the ROM cassette sync/byte routines, aligns to TAP
  leader runs before `$24`, and feeds raw TAP bytes through the patched
  `GETTAPEBYTE` immediate operand. This covers custom loaders that still call
  the ROM tape routines. Tape Load = Off preserves original VIA cassette
  behavior.
- Snapshot LOAD is implemented for RAM, CPU registers, AY registers/current
  register, VIA registers, VIA timers, active flags, and IFR source flags.
  Snapshot SAVE is not implemented.
- Oricutron `.sna` files are typed block containers using 8-byte envelopes and
  big-endian numeric fields. The core honors the minimal Atmos restore set and
  skips tape, patch, disk, Telestrat, symbol, and debug blocks.
- ROM patching is read-side only. It does not modify the BIOS image in memory;
  it substitutes bytes on CPU fetches when a patch gate is active.
