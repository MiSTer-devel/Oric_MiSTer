# Oricutron-compatible snapshot (.sna) support

Working reference for snapshot save/restore in this core. Documents the
file-format contract, the mapping from Oricutron fields to our RTL
signals, and the current implementation status.

## Status

| Direction | State                                                                                  |
| --------- | -------------------------------------------------------------------------------------- |
| **LOAD**  | Working: RAM, CPU, AY register file + creg, VIA register file (12) + timers + IFR, ULA video mode. Via OSD `.sna` load or **F5-F8** hotkey restore from MiSTer savestate slots. |
| **SAVE**  | Implemented (pending on-device verification): **F1-F4** hotkeys save slots 1-4 through the MiSTer Main savestate framework. Emits `OSN + DATA(RAM) + CPU + AY + VIA + PAD`. |

LOAD was built in three passes:

- **v1** restored 64 KiB main RAM and the 6502 register file
  (PC/A/X/Y/S/P). Audio reset to silence and VIA-driven IRQs re-armed
  on the next CPU write.
- **v2** added direct chip-side restore of the 15-byte AY register file
  (with current-register select) and 12 of the 16 VIA registers (ORA,
  ORB, DDRA, DDRB, T1L_L/H, T2L_L/H, SR, ACR, PCR, IER). Audio resumes
  with the captured tones, and VIA timer IRQs run at the right cadence.
- **v3** added VIA internal-state restore: live T1C/T2C counters, the
  t1run/t2run active flags, and the IFR per-source IRQ flags
  (t1_irq/t2_irq/ca1/ca2/cb1/cb2/sr_irq). Required for snapshots taken
  mid-frame on games that pace music/animation off VIA T1 IRQs (e.g.
  Xenon3) — without v3 the timer phase resets to the latch on resume
  and the game freezes on the first screen change. Critical bug found
  and fixed during v3: T1C/T2C are encoded **big-endian** in the .sna
  file (Oricutron's `putu16` writes high byte first — see
  `snapshot.c:67-74`); our initial little-endian capture loaded
  garbage values like `$3412` for a snap-time `$1234` and the timer
  restore appeared inert until the byte order was corrected.
- **Post-v3 fixes** covered two loader edge cases found by Xenon3 and
  Pulsoids. Pulsoids is 148,580 bytes, so the original 128 KiB
  `snapcache` wrapped and corrupted later block parsing; the cache is
  now 192 KiB. Xenon3 and Pulsoids both resume with PC in RAM, so
  `S_DRAIN` now keeps `snap_active` asserted while reading `mem[PC]`
  before releasing T65. Pulsoids also stores `OSN+16 vid_mode = 6`
  (hires + 50 Hz); restoring RAM is not enough because the RTL ULA's
  internal mode register only changes when a mode attribute is later
  scanned. The loader now restores that ULA mode before CPU release.

What's intentionally **not** restored — see [what's not yet
implemented](#whats-not-yet-implemented) for the rationale and the
remaining v4 candidate list.

## Why snapshots

The DMA tape loader breaks any program that self-relocates between
segments (e.g. `games/Oric/tap/scubadive.tap`'s BASIC loader at `$0501` that copies
itself to `$8501`, then CLOADs MC payloads that overwrite `$0400-$3400`).
Rather than reverse-engineering each loader's quirks, we capture the
full machine state once after the program is loaded and running, then
restore from that snapshot in milliseconds.

The format is **Oricutron-compatible** so files round-trip with the
desktop emulator (`pete-gordon/oricutron`).

## File format

- **Extension:** `.sna`
- **Endianness:** big-endian for all multi-byte numeric fields
- **Container:** sequence of typed blocks; max file size 192 KiB
- **Authoritative reference:** `snapshot.c` in
  https://github.com/pete-gordon/oricutron. The field tables below were
  cross-checked against that source and validated by walking a real
  Oricutron-saved `.sna` with `tools/sna-inspect.py`.

### Block envelope

Every block is:

| Offset | Size | Field   | Value                                                         |
| ------ | ---- | ------- | ------------------------------------------------------------- |
| 0      | 4    | tag     | 4-byte ASCII tag, NUL-padded (e.g. `"OSN\0"`)                 |
| 4      | 4    | size    | u32 BE — payload size in bytes (excludes the 8-byte envelope) |
| 8      | size | payload | block-specific data                                           |

Blocks may appear in any order. A reader skips unknown tags by reading
`size` and seeking forward.

### Blocks we honour on LOAD

We honour the **minimum block set needed to restore an Atmos snapshot**.
All other Oricutron blocks are skipped on load. Oricutron itself handles
missing optional blocks gracefully on the desktop side, so files we
might emit later in the SAVE direction will round-trip.

| Tag       | Size  | Purpose                                                |
| --------- | ----- | ------------------------------------------------------ |
| `OSN\0`   | 21    | Machine config (model, video, etc.)                    |
| `DATA`*   | 81920 | RAM image (follows `OSN`, 80 KiB on Atmos — see below) |
| `CPU\0`   | 21    | 6502 register file + IRQ/NMI state                     |
| `AY\0\0`  | 153   | AY-3-8912 register file + oscillator/envelope state    |
| `VIA\0`   | 39    | 6522 register file + timer counters + line states      |

\* Oricutron emits the RAM payload as a `DATA` envelope immediately
following `OSN`. **For Atmos** `oric->memsize` is `65536 + 16384` bytes
(the extra 16 KiB is the disk-overlay RAM that always exists in the
machine struct, even when no drive is attached). Our core only has 64 KiB
of main RAM — when **saving** for Oricutron, pad the upper 16 KiB with
zeros; when **loading** an Oricutron snapshot, ignore the upper 16 KiB.

**Block ordering matters for the parent→DATA association.** Oricutron
walks blocks linearly and treats any `DATA` block as belonging to the
preceding non-`DATA` block (`bkh[i-1].datablock = &bkh[i]`). So the
canonical order is:

```
OSN, DATA(RAM), [TAP, DATA(tape buffer)], [PCH], CPU, AY, VIA, [optional ...]
```

Optional blocks Oricutron writes when applicable but does not require on
load: `TAP\0` + its `DATA`, `PCH\0`, drive blocks (`JSM`, `MDC`, `PRV` +
`PVD`, `WDD`, `DSK`), Telestrat blocks (`BNK`, `ACI`, `AUX`, `TVA`),
symbol blocks (`SYR`, `SYU`, `SY0..SY7`), breakpoints (`BKP`).

### Field-level mapping (our core ↔ Oricutron fields)

For each block, fields are marked with their LOAD status:

- **[done]** — restored by v1, v2, or v3 LOAD
- **[skip]** — intentionally not restored (Oricutron-internal scratch
  that's regenerated, derived from other state we do restore, or
  controller/Telestrat fields irrelevant to Atmos v1)
- **[v4]** — candidate for v4: AY oscillator phase, VIA
  shift-register count, etc. Currently skipped; the program may glitch
  briefly on resume in audio waveform position or mid-shift SR
  state, but neither is known to break gameplay

#### `OSN\0` (21 bytes)

| Off | Size | Field                | Source                                          |
| --- | ---- | -------------------- | ----------------------------------------------- |
| 0   | 1    | machine type         | **[skip]** read but not validated               |
| 1   | 4    | overclock multiplier | **[skip]**                                      |
| 5   | 4    | overclock shift      | **[skip]**                                      |
| 9   | 2    | vsync timing         | **[skip]** core uses its own VSYNC timing       |
| 11  | 1    | rom disable flag     | **[skip]**                                      |
| 12  | 1    | rom enable flag      | **[skip]**                                      |
| 13  | 1    | vsync hack flag      | **[skip]**                                      |
| 14  | 1    | drive type           | **[skip]** v1: no disk                          |
| 15  | 1    | tape turbo flag      | **[skip]**                                      |
| 16  | 1    | video mode           | **[done]** restores ULA mode bits before CPU release |
| 17  | 4    | keymap               | **[skip]**                                      |

The OSN block is recognised so that the following `DATA` block is
identified as RAM (the loader walks blocks linearly and only treats a
`DATA` block as RAM when the immediately preceding block was OSN).

Followed by: `DATA` block, **80 KiB** payload (= `oric->memsize`). First
64 KiB is the address-space RAM image (`$0000-$FFFF`) — **[done]**, this
is what gets streamed into our main spram. Upper 16 KiB is the
disk-overlay area Oricutron always allocates; **[skip]** on load (we
don't have an overlay in v1).

#### `CPU\0` (21 bytes)

| Off | Size | Field         | Source                                                                |
| --- | ---- | ------------- | --------------------------------------------------------------------- |
| 0   | 4    | cycle counter | **[skip]** Oricutron-internal                                         |
| 4   | 2    | PC            | **[done]** → T65 `Regs_set[63:48]`                                    |
| 6   | 2    | last PC       | **[skip]** Oricutron scratch                                          |
| 8   | 2    | calc PC       | **[skip]** Oricutron scratch                                          |
| 10  | 2    | calc int      | **[skip]** Oricutron scratch                                          |
| 12  | 1    | NMI flag      | **[skip]**                                                            |
| 13  | 1    | A             | **[done]** → T65 `Regs_set[7:0]`                                      |
| 14  | 1    | X             | **[done]** → T65 `Regs_set[15:8]`                                     |
| 15  | 1    | Y             | **[done]** → T65 `Regs_set[23:16]`                                    |
| 16  | 1    | S             | **[done]** → T65 `Regs_set[39:32]`                                    |
| 17  | 1    | P             | **[done]** → T65 `Regs_set[31:24]`                                    |
| 18  | 1    | IRQ flag      | **[skip]** core re-derives from VIA/disk IRQ lines                    |
| 19  | 1    | NMI count     | **[skip]**                                                            |
| 20  | 1    | calc opcode   | **[skip]**                                                            |

T65's snap branch (in 3 register-clock processes) clears the
inflight-instruction state to the same values as a fresh reset
(IR/MCycle/Set_Addr_To_r/etc.), then loads PC/A/X/Y/S/P from
`Regs_set`. On the next clock the CPU does a clean opcode fetch from
the loaded PC.

#### `VIA\0` (39 bytes)

Authoritative order from `snapshot.c:286-320`.

| Off | Size | Field          | Source                                                                                          |
| --- | ---- | -------------- | ----------------------------------------------------------------------------------------------- |
| 0   | 1    | IFR            | **[done]** v3 — `snap_ifr_we` strobe overrides the 7 source IRQ flags (t1_irq/t2_irq/sr_irq/cb1/cb2/ca1/ca2) across 4 processes; bit 7 IRQ-summary is recomputed combinationally |
| 1   | 1    | IRB            | **[skip]** input shadow                                                                         |
| 2   | 1    | ORB            | **[done]** → snap_we addr `$0`                                                                  |
| 3   | 1    | IRBL (latched) | **[skip]** input shadow                                                                         |
| 4   | 1    | IRA            | **[skip]** input shadow                                                                         |
| 5   | 1    | ORA            | **[done]** → snap_we addr `$1`                                                                  |
| 6   | 1    | IRAL (latched) | **[skip]** input shadow                                                                         |
| 7   | 1    | DDRA           | **[done]** → snap_we addr `$3`                                                                  |
| 8   | 1    | DDRB           | **[done]** → snap_we addr `$2`                                                                  |
| 9   | 1    | T1L_L          | **[done]** → snap_we addr `$4` (latch only — snap branch doesn't fire t1_load_counter)          |
| 10  | 1    | T1L_H          | **[done]** → snap_we addr `$5` (latch only)                                                     |
| 11  | 2    | T1C            | **[done]** v3 — `snap_t1c_we` strobe writes `t1c` directly (BE: hi@+11, lo@+12)                 |
| 13  | 1    | T2L_L          | **[done]** → snap_we addr `$8`                                                                  |
| 14  | 1    | T2L_H          | **[done]** → snap_we addr `$9`                                                                  |
| 15  | 2    | T2C            | **[done]** v3 — `snap_t2c_we` strobe writes `t2c` directly (BE: hi@+15, lo@+16)                 |
| 17  | 1    | SR             | **[done]** → snap_we addr `$A` (direct write, bypasses sr_write_ena)                            |
| 18  | 1    | ACR            | **[done]** → snap_we addr `$B`                                                                  |
| 19  | 1    | PCR            | **[done]** → snap_we addr `$C`                                                                  |
| 20  | 1    | IER            | **[done]** → snap_we addr `$E` (direct write, bypasses bit-7 set/clear protocol)                |
| 21  | 1    | CA1            | **[skip]** line state — handshake re-arms on next CPU access                                    |
| 22  | 1    | CA2            | **[skip]** line state                                                                           |
| 23  | 1    | CB1            | **[skip]** line state                                                                           |
| 24  | 1    | CB2            | **[skip]** line state                                                                           |
| 25  | 1    | SR count       | **[v4]** mid-shift count                                                                        |
| 26  | 1    | T1 reload      | **[skip]** Oricutron scratch                                                                    |
| 27  | 1    | T2 reload      | **[skip]** Oricutron scratch                                                                    |
| 28  | 2    | SR time        | **[skip]** Oricutron scratch                                                                    |
| 30  | 1    | T1 run         | **[done]** v3 — `snap_t_active_we` strobe writes `t1c_active`                                   |
| 31  | 1    | T2 run         | **[done]** v3 — `snap_t_active_we` strobe writes `t2c_active`                                   |
| 32  | 1    | CA2 pulse      | **[skip]**                                                                                      |
| 33  | 1    | CB2 pulse      | **[skip]**                                                                                      |
| 34  | 1    | SR trigger     | **[skip]**                                                                                      |
| 35  | 4    | IRQ bit        | **[skip]**                                                                                      |

#### `AY\0\0` (153 bytes)

Authoritative order from `snapshot.c:251-283`. NUM_AY_REGS = 15
(AY-3-8910 register file plus IO Port A index).

| Off | Size | Field                                                | Source                                                       |
| --- | ---- | ---------------------------------------------------- | ------------------------------------------------------------ |
| 0   | 1    | bus mode (`bmode`)                                   | **[skip]** Oricutron-internal                                |
| 1   | 1    | current register (`creg`)                            | **[done]** → `snap_creg_we`                                  |
| 2   | 15   | `eregs[15]` — register file                          | **[done]** → 15 snap_we writes (one per AY register address) |
| 17  | 8    | 8 keystates                                          | **[skip]** keyboard column shadow — re-derived               |
| 25  | 12   | 3 tone periods (u32 each)                            | **[skip]** derived from regs 0-5 (already restored)          |
| 37  | 4    | noise period (u32)                                   | **[skip]** derived from reg 6                                |
| 41  | 4    | envelope period (u32)                                | **[skip]** derived from regs 11-12                           |
| 45  | 18   | per-channel `tonebit/noisebit/vol` (u16×3 each)      | **[v4]** per-channel oscillator phase                        |
| 63  | 2    | newout                                               | **[skip]** Oricutron audio-rendering scratch                 |
| 65  | 12   | per-channel timer `ct[3]` (u32 each)                 | **[v4]** tone counters (`a/b/c_count`)                       |
| 77  | 4    | noise timer `ctn` (u32)                              | **[v4]** noise counter (`n_count`)                           |
| 81  | 4    | envelope timer `cte` (u32)                           | **[v4]** envelope counter                                    |
| 85  | 48   | per-channel `tonepos/tonestep/sign/out` (u32×4 each) | **[skip]** Oricutron audio-rendering scratch                 |
| 133 | 4    | envelope position                                    | **[v4]** envelope phase                                      |
| 137 | 4    | current noise value                                  | **[v4]** noise LFSR                                          |
| 141 | 4    | RNG rack (`rndrack`)                                 | **[v4]** noise LFSR                                          |
| 145 | 4    | key bit delay                                        | **[skip]**                                                   |
| 149 | 4    | current key offset                                   | **[skip]**                                                   |

The 15 AY registers + creg cover the audible-state restore; everything
else in this block is either Oricutron audio-rendering scratch
(regenerated) or live oscillator/envelope state (a v4 candidate — would
need internal `*_count` and `*_ff` signals plumbed out of `psg.v`).

### Whole blocks we ignore on LOAD

- **Tape state (`TAP`)** — tape is irrelevant once a program is loaded.
- **ROM patches (`PCH`)** — Oricutron's fast-disk/fast-tape patches; n/a.
- **Disk controller blocks** (`MDC`, `WDD`, `JSM`, `PRV`, `DSK`) — no disk support yet.
- **Telestrat blocks** (`BNK`, `ACI`, `AUX`, `TVA`) — Atmos-only core.
- **Debug blocks** (`SYR`, `SYU`, `BKP`) — never relevant.

These all dispatch to `S_SKIP` in the LOAD state machine: read the size,
seek past the payload, continue.

### Typical file size (minimal block set)

```
"OSN\0"  envelope(8) + 21        =     29 bytes
"DATA"   envelope(8) + 81920     =  81928 bytes
"CPU\0"  envelope(8) + 21        =     29 bytes
"AY\0\0" envelope(8) + 153       =    161 bytes
"VIA\0"  envelope(8) + 39        =     47 bytes
Total                            ≈  82194 bytes (~80 KiB)
```

Reference: a real Oricutron save of scubadive is **99,778 bytes** —
that includes optional `TAP` (46 + tape buffer 13830), `PCH` (76),
and `SYR` (3600) blocks. Our minimal save will be ~80 KiB. Well under
the 192 KiB cap; no compression needed.

## Implementation snapshot (where things landed)

- **Menu / trigger:** `F4,SNA,Load Snapshot;` in `Oric.sv`, ioctl_index
  `4`. File is buffered in the 192 KiB shared FPGA file cache, then a
  state machine walks the typed-block container after `ioctl_download`
  falls.
- **CPU halt:** `snap_active` is OR'd into the `cpu_halt` chain feeding
  `oricatmos.cpu_halt` alongside `tap_active`.
- **RAM restore:** during `S_BLK_DATA_RAM`, the snap state machine
  drives `snap_ram_addr/data/we` through a branch in the main spram
  address-mux — same Pattern B shape as `tap_segment_loader`.
- **PC fetch preload:** during `S_DRAIN`, the loader holds `active`
  and drives `ram_addr = snap_pc` with writes disabled. This lets the
  main spram output settle to the restored PC opcode before the CPU
  halt is released; otherwise snapshots resuming in RAM can fetch stale
  `spram_q` from the loader's last RAM access.
- **CPU register restore:** new `Regs_set[63:0]` + `Regs_set_we` ports
  on T65 with snap branches in three register-clock processes (PC/S +
  inflight state, P/X/Y/A, MCycle/RstCycle).
- **AY/VIA register restore:** new `snap_we`/`snap_addr`/`snap_data`
  ports on `psg.v` and `m6522.vhd` (plus `snap_creg_we`/`snap_creg` on
  the AY) with parallel write branches in each chip's existing
  register-write process. Restore drives them from `Oric.sv` — no bus
  muxing required at the oricatmos level.
- **VIA timer + IFR restore (v3):** four extra strobes on `m6522.vhd`
  — `snap_t1c_we` (16-bit data), `snap_t2c_we` (16-bit data),
  `snap_t_active_we` (writes `t1c_active`/`t2c_active`), and
  `snap_ifr_we` (7-bit data, one bit per IRQ source). The IFR strobe
  has to fire from inside four different processes (`p_timer1`,
  `p_timer2`, `p_ca_cb_irq`, and the SR process) because each owns
  its own source-IRQ register. After the v2 register apply finishes,
  `snap_loader.v` enters `S_APPLY_VIA_TIMERS` and pulses the four
  strobes one cycle each before moving on to AY apply.
- **ULA mode restore:** `OSN+16` is captured and driven into the ULA
  during the pre-release drain window so snapshots that resume before
  the next mode attribute still select the correct text/hires and
  50/60 Hz state. This is required for Pulsoids, whose current hires
  screen does not put a mode attribute at the first scanned byte after
  restore.
- **Debug visibility:** optional `SNAP_DEBUG` Verilog macro paints the
  captured CPU regs at row 10 of the text screen so you can verify the
  decoder visually. Turn it on with `tools/oric-build --snap-debug`;
  defaults off in release builds.

## What's not yet implemented

### v4 candidates (all flagged **[v4]** in the field tables above)

- **VIA shift-register count** (offset 25) — affects programs that
  resume mid-shift. Rare on Atmos; not implemented.
- **AY oscillator state** — tone counters (`a/b/c_count`), tone
  flip-flops (`a/b/c_ff`), noise counter and LFSR, envelope phase. Not
  restoring these means the first audio frame after resume has the
  right tone/volume but slightly wrong waveform position; usually
  inaudible after a few ms. Would need internal `*_count` and `*_ff`
  signals plumbed out of `psg.v`.

### v3 work that explicitly skipped some fields

- **OSN +9 vsync countdown** — Oricutron tracks where in the
  current frame it is so VIA CB1 fires at exactly the right line. Our
  ULA generates VSYNC from its own line counter and the visible glitch
  on resume is one frame at most, so we don't restore it.
- **CPU +12 nmi / +18 irq flags** — the T65 re-derives these from the
  VIA O_IRQ_L line on the next cycle after resume; there's no benefit
  to forcing them.

## SAVE direction (savestates)

SAVE goes through the **MiSTer Main savestate framework** rather than
`ioctl_upload`: the conf_str declares `SS3E000000:200000` (4 slots of
2 MiB in DDR at 0x3E000000), Main pre-loads existing `.ss` files into
the slots when a game loads, and writes a slot to
`/media/fat/savestates/Oric/<game>_<slot>.ss` whenever its header
change-counter increments. Each slot starts with the 8-byte Main
header — u32 LE change counter, then u32 LE payload size in dwords —
followed by the payload, which for this core is a plain Oricutron
`.sna` block container. `tools/ss-convert.py` converts both ways
(strip/prepend the header; pad with a `PAD\0` block since Oricutron's
block walker rejects bare trailing bytes).

### Hotkeys

`rtl/savestate_hotkeys.v`: **F1-F4** save to slots 1-4, **F5-F8**
restore from slots 1-4 (the Oric keyboard only uses F10/F11). Gated by
`allow_ss` in `Oric.sv`: something must be loaded (TAP, SNA or disk)
and no download/reset/loader may be active. OSD info toasts ("Saved
state N" / "Restored state N" / "Slot is empty") confirm each action.

### Engine (`rtl/snap_ss.v`)

- **SAVE**: reads the slot's old counter, requests an
  instruction-boundary CPU stall (`save_halt`/`save_halted` handshake
  in `oricatmos.vhd` — the Rdy stall engages only while T65 is parked
  at an opcode fetch with `Sync='1'`, so the captured PC is the exact
  resume address), latches the whole VIA state bus in one cycle
  (`m6522.snap_q[136:0]` — tear-free even though the timers keep
  running), walks the 15 AY registers (`psg.snap_rd_*`, static while
  the CPU is halted), then streams the block container into DDR at
  one byte per 3 cycles (the registered spram mux + BRAM output make
  RAM reads 2-cycle latent) packed into 64-bit beats. The header is
  written **last** so Main never snapshots a half-written slot.
  ~12 ms total; the machine resumes as if RDY had been held.
- **LOAD**: validates the slot header (size in (0, 192 KiB] — a range
  check, not exact-match, so converted Oricutron snapshots of any size
  load), DMAs the payload into the shared 192 KiB filecache and
  retriggers `snap_loader` via its `start` input — the apply path is
  identical to an OSD `.sna` load, including PC preload and ULA mode
  restore. Hotkey loads clobber the shared TAP/SNA cache, same as an
  OSD `.sna` load.

### Emitted values (SAVE)

Blocks in canonical order `OSN, DATA, CPU, AY, VIA, PAD` — payload
82204 bytes (20551 dwords), `.ss` file 82212 bytes.

- **OSN**: machine type from the ROM selection (Atmos→2, Oric-1→0,
  Pravetz→4, loadable BIOS→2; Oricutron's `memsize` is 81920 for all
  three, so `DATA` is always 64 KiB RAM + 16 KiB zero overlay pad),
  overclock mult=1, vsync=272 (matches real Oricutron saves), romon=1,
  vid_mode from the ULA's `lREG_MODE` **latched once per frame at
  scanline 100** — the live register flips to text every frame while
  the bottom three text rows (and vblank) scan out, so sampling it at
  a random beam position broke hires restores; everything else 0.
- **CPU**: PC/lastpc/calcpc = T65 `Regs` PC, A/X/Y/S/P (P bit 5 forced
  1), `irq` = IFR bit 7 so a pending VIA IRQ fires on resume in
  Oricutron; cycles/nmi/scratch = 0.
- **AY**: creg + 15 registers, plus the derived fields Oricutron uses
  directly until the next register write: toneper = period×8,
  noiseper = period×8, envper = period×16, tonebit/noisebit from
  reg 7, vol = voltab[level or envelope level] (16-entry `voltab/4`
  LUT). Dynamic phase counters (ct/ctn/cte/envpos/LFSR) stay 0 — the
  same [v4] class our LOAD skips.
- **VIA**: full register file + live T1C/T2C + t1run/t2run + IFR.
  Input shadows (IRB/IRA/latches) and CA/CB line states are 0 (the
  fields LOAD also skips). **irqbit = 1 (`IRQF_VIA`)** — Oricutron
  consumes this on load; emitting 0 would permanently detach VIA IRQs
  from the emulated CPU.
- **PAD** (size 2): dword alignment as a real block — Oricutron skips
  unknown tags but rejects bare trailing bytes and size-0 blocks.

### Other Oricutron blocks we don't emit

`TAP`, `PCH`, `SYR`, disk blocks (`MDC`/`WDD`/`JSM`/`PRV`/`DSK`),
Telestrat blocks: irrelevant or out of scope (disk/overlay state is a
documented v2 candidate — snapshots taken mid-disk-I/O will not
restore FDC state). Oricutron loads files with missing optional blocks
without complaint.

## Tooling

`tools/sna-inspect.py` — walks the block container and decodes every
known block's fields against the layouts above. Sanity-checked against
a real `scubadive.sna` saved by Oricutron 1.x (Atmos, no drive). All
expected sizes (`OSN=21`, `CPU=21`, `AY=153`, `VIA=39`, `TAP=46`,
`PCH=76`, `DATA=81920` for Atmos RAM) matched on first run, and the
decoded TXTTAB (`$8501`) matches scubadive's known runtime relocation
behaviour — strong evidence the layout above is correct.

```sh
python3 tools/sna-inspect.py path/to/snapshot.sna
```

## Verification log

1. Hand-craft a minimal `.sna` (correct envelopes, all-zero payloads,
   plain RAM dump lifted from `scubadive.sna`) and confirm Oricutron
   loads it without error. **DONE** for ground-truth verification.
2. Walk a real Oricutron save with `tools/sna-inspect.py` and
   cross-check fields against the tables above. **DONE** —
   pre-implementation; caught the `\x00` Verilog string-literal trap
   later in v1 RTL.
3. **v1 hardware test** — Oricutron-saved `scubadive.sna`, `gravitor.sna`,
   and a hand-made `simple_basic.sna` loaded via `F4`. CPU resumed from
   the captured PC; RAM contents matched. Audio silent until the
   program rewrote AY (expected; v1 didn't restore audio). **DONE.**
4. **v2 hardware test** — same snapshots reloaded after AY/VIA register
   restore landed. Audio resumes with the captured tones; VIA-driven
   IRQs run at the right cadence. **DONE.**
5. **v3 hardware test** — Xenon3 snapshot. Pre-v3 the game froze on
   the first screen change because T1 IRQ pacing was off. With v2
   register state alone the freeze persisted. With v3 (T1C/T2C/run
   flags + IFR restore) the game resumes and runs cleanly. The
   T1C/T2C big-endian fix was the load-bearing change — earlier v3
   builds with little-endian capture appeared inert. **DONE.**
6. **Large snapshot cache test** — Pulsoids is 148,580 bytes and was
   the only current snapshot found above the old 128 KiB cache limit.
   The cache is now 192 KiB with guarded download writes, so Pulsoids'
   later `CPU`/`AY`/`VIA` blocks parse from the correct offsets instead
   of wrapped data. **DONE.**
7. **PC preload test** — Xenon3 and Pulsoids both resume with PC in
   restored RAM (`Xenon3=$3DDF`, `Pulsoids=$710E`). Keeping the loader's
   RAM mux active through `S_DRAIN` and reading `mem[PC]` before CPU
   release fixed stale-opcode fetches; Xenon3 now loads and runs.
   **DONE.**
8. **Pulsoids ULA mode test** — `tools/sna-inspect.py` reports
   `vid_mode 6` for Pulsoids. Without restoring `OSN+16`, music resumes
   but graphics stay in the wrong mode because the ULA waits for a
   scanned mode attribute. Loading `lREG_MODE` during `S_DRAIN` restores
   hires + 50 Hz before execution continues. **DONE.**
9. **SAVE hardware tests** (2026-06-10 build) — **DONE**:
   - F1 on a running game produced `<game>_1.ss` (82,212 bytes, exact
     predicted size) in `/media/fat/savestates/Oric/` within a second —
     Main's counter-watch picked up the header write.
   - F5 restored the saved state exactly and the machine kept running
     (Scuba Dive: game playable after restore).
   - Oricutron `pulsoids.sna` (148 KB) converted with
     `ss-convert.py to-ss`, dropped in as slot 2, loaded via F6 —
     exercises the loose size validation, the large DDR→filecache DMA
     and hires ULA mode restore.
   - F7 on an empty slot: rejected safely, machine untouched.
   - Xenon3 F1→F5 mid-music round trip: resumes with music; the saved
     file decodes with live `T1C` mid-count vs the `$2710` latch,
     t1run/t2run set, ACR=$40, irqbit=1, and the AY derived fields
     (toneper ×8, envper ×16, voltab vols, interleaved
     tonebit/noisebit/vol — a field-order bug found and fixed on the
     first hardware save) all correct.
10. **Hires save bug + fix** (2026-06-10) — **DONE**: live-sampling
   `lREG_MODE` captured `vid_mode = text` when F1 landed while a
   mode-switching game had the register in its text window, restoring
   to a text screen. Fixed by latching the mode at scanline 100.
   Verified: 4 Pulsoids saves at random moments all capture the hires
   bit and restore in hires. Note the low bits (50/60 Hz, unused bit 0)
   still vary save-to-save on Pulsoids — the game itself rewrites mode
   attributes per frame (raster tricks), so each captured value is one
   the game wrote; it re-asserts its attributes within a frame of
   restore and all variants restore correctly.
11. **Desktop Oricutron load of a MiSTer save** — convert with
   `ss-convert.py to-sna` and open in Oricutron. **PENDING** — format
   verified byte-by-byte against `snapshot.c` and `sna-inspect.py`,
   but not yet opened in the desktop GUI.

## References

- Oricutron source — `snapshot.c`:
  https://github.com/pete-gordon/oricutron/blob/master/snapshot.c
- Oricutron repository:
  https://github.com/pete-gordon/oricutron
- Forum thread on `.sna` layout:
  https://forum.defence-force.org/viewtopic.php?t=1001&start=150
- `tools/sna-inspect.py` — block walker / field decoder (in this repo)
