# Oric / Oric Atmos for MiSTer

This repository contains an Oric-1, Oric Atmos, and Pravetz 8D FPGA core for
the MiSTer platform. The current development focus is making the core practical
for day-to-day software use: TAP loading, snapshot restore, ROM selection,
Microdisc support, and MiSTer launcher files.

The core descends from the earlier MiST / SiDi Oric FPGA work. The original
project notes and credits are preserved below, but this README now reflects the
current MiSTer tree.

## Current Status

Implemented and actively maintained:

- Oric-1 and Oric Atmos operation with full 64 KiB RAM.
- Pravetz 8D ROM option with proper keymapping
- ULA video, 6502 CPU, VIA 6522, AY-3-8912 sound and keyboard matrix handling.
- Microdisc support with EDSK / CPC DSK images.
- TAP loading through the MiSTer file loader.
- Original cassette-audio loading path via VIA cassette input behavior.
- Smart CLOAD menu with three modes:
  - `Fast`: default mode, keeps the ROM tape flow in charge while feeding TAP
    bytes directly and aligning ROM sync to TAP leader bytes.
  - `Ultra`: segment-copy loader for simple CLOAD flows.
  - `Off`: original cassette/VIA behavior.
- Autoload TAP setting for resetting into `CLOAD""` after a TAP is selected.
- Oricutron-compatible `.sna` snapshot loading for RAM, CPU, AY and VIA state.
- MGL launcher samples for TAP files and snapshots.

Snapshot SAVE is not implemented.

## Repository Layout

- `rtl/` - VHDL/Verilog implementation modules.
- `dsk/` - disk images in the supported EDSK format.
- `releases/` - checked-in release `.rbf` builds.

## Disk Images

Despite the `.dsk` extension, disk images must use the de facto EDSK / CPC DSK
format. To convert Oric disk images, use HxCFloppyEmulator and export as
`CPC DSK file`, keeping the `.dsk` extension for MiSTer use.

If a disk is bootable, select it from the OSD, exit the OSD, then reset the
core. If it is not bootable, try `DIR` and then `!NAME_OF_FILE_TO_RUN`.

## Original Project Credits

This core builds on earlier Oric FPGA preservation work for MiST and SiDi.

- Ron Rodritty: team coordination and QA testing.
- Fernando Mosquera: FPGA.
- Subcritical: Verilog and VHDL.
- ManuFerHi: hardware consulting.
- Chema Enguita: Oric software.
- SiliceBit: Oric hardware.
- ZXMarce: hardware support.
- Ramon Martinez: Oric hardware, software, and FPGA coding.
- Slingshot: SDRAM work and advice.

Thanks also to Sorgelig, Gehstock, DesUBIKado, RetroWiki, and friends.
