#!/usr/bin/env python3
"""Inspect an Oricutron .sna snapshot file.

Walks the typed-block container and decodes known blocks (OSN, DATA, TAP,
PCH, CPU, AY, VIA). Field layouts derived from Oricutron's snapshot.c
(pete-gordon/oricutron). Big-endian throughout.
"""

import argparse
import struct
import sys
from pathlib import Path


MACH = {0: "Oric-1", 1: "Oric-1 16K", 2: "Atmos", 3: "Telestrat", 4: "Pravetz"}
DRV  = {0: "none", 1: "Jasmin", 2: "Microdisc", 3: "Pravetz"}


def tag_str(tag: bytes) -> str:
    return "".join(chr(b) if 0x20 <= b < 0x7F else "." for b in tag)


def hex_preview(p: bytes, n: int = 32) -> str:
    head = " ".join(f"{b:02X}" for b in p[:n])
    return head + (" ..." if len(p) > n else "")


def kv(label: str, val) -> None:
    print(f"  {label:<26}{val}")


def read_blocks(data: bytes):
    """Yield (file_offset, tag, payload). Stops on truncation."""
    off = 0
    while off + 8 <= len(data):
        tag  = data[off:off + 4]
        size = struct.unpack(">I", data[off + 4:off + 8])[0]
        end  = off + 8 + size
        if end > len(data):
            print(f"  ! truncated: block at {off} declares {size} bytes, "
                  f"only {len(data) - off - 8} available", file=sys.stderr)
            return
        yield off, tag, data[off + 8:end]
        off = end


# ----- per-block decoders -----

def decode_osn(p: bytes) -> None:
    type_b    = p[0]
    ovrmult   = struct.unpack(">I", p[1:5])[0]
    ovrshift  = struct.unpack(">I", p[5:9])[0]
    vsync     = struct.unpack(">H", p[9:11])[0]
    romdis    = p[11]
    romon     = p[12]
    vsynchack = p[13]
    drv       = p[14]
    tapeturbo = p[15]
    vid_mode  = p[16]
    keymap    = struct.unpack(">I", p[17:21])[0]
    kv("machine type",          f"{type_b}  ({MACH.get(type_b, '?')})")
    kv("drive type",            f"{drv}  ({DRV.get(drv, '?')})")
    kv("vid_mode",              vid_mode)
    kv("vsync",                 vsync)
    kv("romdis / romon",        f"{romdis} / {romon}")
    kv("vsync hack",            vsynchack)
    kv("tape turbo",            tapeturbo)
    kv("overclock mult / shift", f"{ovrmult} / {ovrshift}")
    kv("keymap",                keymap)


def decode_cpu(p: bytes) -> None:
    cycles  = struct.unpack(">I", p[0:4])[0]
    pc      = struct.unpack(">H", p[4:6])[0]
    lastpc  = struct.unpack(">H", p[6:8])[0]
    calcpc  = struct.unpack(">H", p[8:10])[0]
    calcint = struct.unpack(">H", p[10:12])[0]
    nmi, a, x, y, sp, P, irq, nmicount, calcop = p[12:21]
    flag_chars = "NV-BDIZC"
    flag_str = "".join(c if (P >> (7 - i)) & 1 else "." for i, c in enumerate(flag_chars))
    kv("PC",                f"${pc:04X}")
    kv("A / X / Y",         f"${a:02X} / ${x:02X} / ${y:02X}")
    kv("S",                 f"${sp:02X}")
    kv("P",                 f"${P:02X}  {flag_str}")
    kv("cycles",            cycles)
    kv("lastpc / calcpc",   f"${lastpc:04X} / ${calcpc:04X}")
    kv("calcint / calcop",  f"${calcint:04X} / ${calcop:02X}")
    kv("nmi / nmicount",    f"{nmi} / {nmicount}")
    kv("irq",               irq)


def decode_via(p: bytes) -> None:
    fields = [
        ("IFR",        1), ("IRB",  1), ("ORB",  1), ("IRBL", 1),
        ("IRA",        1), ("ORA",  1), ("IRAL", 1),
        ("DDRA",       1), ("DDRB", 1),
        ("T1L_L",      1), ("T1L_H", 1), ("T1C",  2),
        ("T2L_L",      1), ("T2L_H", 1), ("T2C",  2),
        ("SR",         1), ("ACR",  1), ("PCR",  1), ("IER", 1),
        ("CA1",        1), ("CA2",  1), ("CB1",  1), ("CB2", 1),
        ("SR count",   1), ("T1 reload", 1), ("T2 reload", 1),
        ("SR time",    2),
        ("T1 run",     1), ("T2 run", 1),
        ("CA2 pulse",  1), ("CB2 pulse", 1), ("SR trigger", 1),
        ("IRQ bit",    4),
    ]
    o = 0
    for name, sz in fields:
        if sz == 1:
            val = f"${p[o]:02X}"
        elif sz == 2:
            val = f"${struct.unpack('>H', p[o:o + 2])[0]:04X}"
        else:
            val = f"${struct.unpack('>I', p[o:o + 4])[0]:08X}"
        kv(name, val)
        o += sz


def decode_ay(p: bytes) -> None:
    o = 0
    bmode = p[o]; o += 1
    creg  = p[o]; o += 1
    eregs = p[o:o + 15]; o += 15
    keystates = p[o:o + 8]; o += 8
    toneper = struct.unpack(">III", p[o:o + 12]); o += 12
    noiseper = struct.unpack(">I", p[o:o + 4])[0]; o += 4
    envper   = struct.unpack(">I", p[o:o + 4])[0]; o += 4
    chans1 = []
    for _ in range(3):
        tb = struct.unpack(">H", p[o:o + 2])[0]; o += 2
        nb = struct.unpack(">H", p[o:o + 2])[0]; o += 2
        vol = struct.unpack(">H", p[o:o + 2])[0]; o += 2
        chans1.append((tb, nb, vol))
    newout = struct.unpack(">H", p[o:o + 2])[0]; o += 2
    ct = struct.unpack(">III", p[o:o + 12]); o += 12
    ctn = struct.unpack(">I", p[o:o + 4])[0]; o += 4
    cte = struct.unpack(">I", p[o:o + 4])[0]; o += 4
    chans2 = []
    for _ in range(3):
        tp = struct.unpack(">I", p[o:o + 4])[0]; o += 4
        ts = struct.unpack(">I", p[o:o + 4])[0]; o += 4
        sg = struct.unpack(">I", p[o:o + 4])[0]; o += 4
        ou = struct.unpack(">I", p[o:o + 4])[0]; o += 4
        chans2.append((tp, ts, sg, ou))
    envpos      = struct.unpack(">I", p[o:o + 4])[0]; o += 4
    currnoise   = struct.unpack(">I", p[o:o + 4])[0]; o += 4
    rndrack     = struct.unpack(">I", p[o:o + 4])[0]; o += 4
    keybitdelay = struct.unpack(">I", p[o:o + 4])[0]; o += 4
    currkeyoffs = struct.unpack(">I", p[o:o + 4])[0]; o += 4

    kv("bmode / creg",      f"{bmode} / {creg}")
    kv("eregs (15)",        " ".join(f"{b:02X}" for b in eregs))
    print(f"    R0/R1 chA period lo/hi   = {eregs[0]:02X} {eregs[1]:02X}")
    print(f"    R2/R3 chB period lo/hi   = {eregs[2]:02X} {eregs[3]:02X}")
    print(f"    R4/R5 chC period lo/hi   = {eregs[4]:02X} {eregs[5]:02X}")
    print(f"    R6 noise period          = {eregs[6]:02X}")
    print(f"    R7 mixer/IO              = {eregs[7]:02X}")
    print(f"    R8/9/10 amp A/B/C        = {eregs[8]:02X} {eregs[9]:02X} {eregs[10]:02X}")
    print(f"    R11/R12 env period       = {eregs[11]:02X} {eregs[12]:02X}")
    print(f"    R13 env shape            = {eregs[13]:02X}")
    print(f"    R14 IO port A            = {eregs[14]:02X}")
    kv("keystates",         " ".join(f"{b:02X}" for b in keystates))
    kv("tone period A/B/C", f"{toneper[0]} / {toneper[1]} / {toneper[2]}")
    kv("noise period",      noiseper)
    kv("envelope period",   envper)
    for i, (tb, nb, vol) in enumerate(chans1):
        kv(f"chan {chr(ord('A') + i)} tone/noise/vol", f"{tb} / {nb} / {vol}")
    kv("new output",        newout)
    kv("ct A/B/C",          f"{ct[0]} / {ct[1]} / {ct[2]}")
    kv("ctn (noise)",       ctn)
    kv("cte (envelope)",    cte)
    for i, (tp, ts, sg, ou) in enumerate(chans2):
        kv(f"chan {chr(ord('A') + i)} pos/step/sign/out", f"{tp} / {ts} / {sg} / {ou}")
    kv("envpos",            envpos)
    kv("currnoise / rndrack", f"{currnoise} / {rndrack}")
    kv("keybitdelay / currkeyoffs", f"{keybitdelay} / {currkeyoffs}")


def decode_tap(p: bytes) -> None:
    o = 0
    tapebit, tapeout, tapeparity = p[o:o + 3]; o += 3
    fields = [("tapelen", 4), ("tapeoffs", 4), ("tapecount", 4),
              ("tapetime", 4), ("tapedupbytes", 4), ("tapehdrend", 4),
              ("tapedelay", 4)]
    vals = {}
    for name, sz in fields:
        vals[name] = struct.unpack(">I", p[o:o + sz])[0]; o += sz
    tapemotor, tapeturbo_forceoff, rawtape = p[o:o + 3]; o += 3
    nonrawend           = struct.unpack(">I", p[o:o + 4])[0]; o += 4
    tapehitend          = struct.unpack(">I", p[o:o + 4])[0]; o += 4
    tapeturbo_syncstack = struct.unpack(">I", p[o:o + 4])[0]; o += 4

    kv("tapebit/out/parity", f"{tapebit} / {tapeout} / {tapeparity}")
    for name, _ in fields:
        kv(name, vals[name])
    kv("motor / turbo-forceoff / raw", f"{tapemotor} / {tapeturbo_forceoff} / {rawtape}")
    kv("nonrawend",            nonrawend)
    kv("tapehitend",           tapehitend)
    kv("tapeturbo_syncstack",  tapeturbo_syncstack)


def decode_data(p: bytes, prev_tag: bytes | None) -> None:
    kv("size",       f"{len(p)} bytes")
    if prev_tag == b"OSN\x00":
        kv("contents", "main RAM (oric->mem; 80 KiB on Atmos)")
        if len(p) >= 0xA2:
            kv("$0001 (port reg)",   f"${p[0x01]:02X}")
            kv("$009A/9B (TXTTAB)",  f"${p[0x9B] << 8 | p[0x9A]:04X}")
            kv("$009C/9D (VARTAB)",  f"${p[0x9D] << 8 | p[0x9C]:04X}")
            kv("$009E/9F (ARYTAB)",  f"${p[0x9F] << 8 | p[0x9E]:04X}")
            kv("$00A0/A1 (STREND)",  f"${p[0xA1] << 8 | p[0xA0]:04X}")
    elif prev_tag == b"TAP\x00":
        kv("contents", "tape buffer (oric->tapebuf; size = TAP.tapelen)")
    kv("first 32 bytes", hex_preview(p))


DECODERS = {
    b"OSN\x00":   decode_osn,
    b"CPU\x00":   decode_cpu,
    b"VIA\x00":   decode_via,
    b"AY\x00\x00": decode_ay,
    b"TAP\x00":   decode_tap,
}

EXPECTED_SIZE = {
    b"OSN\x00":    21,
    b"CPU\x00":    21,
    b"VIA\x00":    39,
    b"AY\x00\x00": 153,
    b"TAP\x00":    46,
    b"PCH\x00":    76,
    b"WDD\x00":    38,
    b"BNK\x00":     9,
    b"ACI\x00":     5,
    b"AUX\x00":     5,
    b"TVA\x00":    39,
    b"PAD\x00":     2,  # dword-alignment filler emitted by our SAVE
}

SEP = "=" * 60


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    ap.add_argument("file", type=Path, help="path to .sna file")
    args = ap.parse_args()

    data = args.file.read_bytes()
    print(f"file   : {args.file}  ({len(data)} bytes)")

    blocks = list(read_blocks(data))
    print(f"blocks : {len(blocks)}")

    prev_tag = None
    for off, tag, payload in blocks:
        print()
        print(SEP)
        size_note = ""
        expected = EXPECTED_SIZE.get(tag)
        if expected is not None and expected != len(payload):
            size_note = f"  ! expected {expected}, got {len(payload)}"
        print(f"  {tag_str(tag)}  (offset {off}, payload {len(payload)}){size_note}")
        print(SEP)

        decoder = DECODERS.get(tag)
        if decoder:
            decoder(payload)
        elif tag == b"DATA":
            decode_data(payload, prev_tag)
        else:
            kv("size", f"{len(payload)} bytes  (decoder not implemented)")
            kv("first 32 bytes", hex_preview(payload))

        prev_tag = tag

    return 0


if __name__ == "__main__":
    sys.exit(main())
