#!/usr/bin/env python3
"""Convert between MiSTer savestate (.ss) and Oricutron snapshot (.sna) files.

A MiSTer Oric savestate is an Oricutron .sna block container prefixed
with the 8-byte MiSTer Main savestate header:

    bytes 0-3   u32 LE   change counter (Main saves the slot when it changes)
    bytes 4-7   u32 LE   payload size in dwords (Main writes (size+2)*4 bytes)

Subcommands:
    to-sna  in.ss  out.sna     strip the header -> loadable in Oricutron
    to-ss   in.sna out.ss      pad to a dword boundary (with a real "PAD"
                               block -- Oricutron rejects bare trailing
                               bytes) and prepend the header; drop the
                               file in savestates/Oric/<game>_<slot>.ss
    inspect in.ss              decode the header, then run sna-inspect
                               on the embedded payload
"""

import argparse
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

HEADER_LEN = 8


def read_header(data: bytes, name: str) -> tuple[int, int]:
    if len(data) < HEADER_LEN:
        sys.exit(f"{name}: too short for a .ss header ({len(data)} bytes)")
    counter, size_dw = struct.unpack("<II", data[:HEADER_LEN])
    return counter, size_dw


def cmd_to_sna(args) -> int:
    data = args.infile.read_bytes()
    counter, size_dw = read_header(data, str(args.infile))
    payload_len = size_dw * 4
    avail = len(data) - HEADER_LEN
    if payload_len == 0 or payload_len > avail:
        sys.exit(f"{args.infile}: header declares {payload_len} payload bytes, "
                 f"file holds {avail} — not a valid Oric .ss file")
    if payload_len != avail:
        print(f"note: {avail - payload_len} trailing bytes beyond the declared "
              f"payload are dropped")
    payload = data[HEADER_LEN:HEADER_LEN + payload_len]
    if payload[:3] != b"OSN":
        print("warning: payload does not start with an OSN block — "
              "Oricutron may reject it", file=sys.stderr)
    args.outfile.write_bytes(payload)
    print(f"{args.outfile}: {payload_len} bytes (counter was {counter})")
    return 0


def cmd_to_ss(args) -> int:
    payload = bytearray(args.infile.read_bytes())
    if payload[:3] != b"OSN":
        print("warning: input does not start with an OSN block — "
              "is this an Oricutron .sna?", file=sys.stderr)
    pad = (4 - len(payload) % 4) % 4
    if pad:
        # a real block, not bare bytes: Oricutron's block walker rejects
        # trailing garbage and zero-size blocks but skips unknown tags
        payload += b"PAD\x00" + struct.pack(">I", pad) + bytes(pad)
        print(f"appended PAD block ({pad} payload bytes) for dword alignment")
    size_dw = len(payload) // 4
    header = struct.pack("<II", args.counter, size_dw)
    args.outfile.write_bytes(header + payload)
    print(f"{args.outfile}: {len(payload) + HEADER_LEN} bytes "
          f"(payload {size_dw} dwords, counter {args.counter})")
    return 0


def cmd_inspect(args) -> int:
    data = args.infile.read_bytes()
    counter, size_dw = read_header(data, str(args.infile))
    payload_len = size_dw * 4
    print(f"file    : {args.infile}  ({len(data)} bytes)")
    print(f"counter : {counter}")
    print(f"size    : {size_dw} dwords = {payload_len} bytes"
          f"  (+8 header = {payload_len + HEADER_LEN})")
    avail = len(data) - HEADER_LEN
    if payload_len == 0 or payload_len > avail:
        sys.exit("header size is inconsistent with the file length")

    sna_inspect = Path(__file__).resolve().parent / "sna-inspect.py"
    if not sna_inspect.exists():
        print("(sna-inspect.py not found next to this script — header only)")
        return 0
    with tempfile.NamedTemporaryFile(suffix=".sna") as tmp:
        tmp.write(data[HEADER_LEN:HEADER_LEN + payload_len])
        tmp.flush()
        return subprocess.run([sys.executable, str(sna_inspect), tmp.name]).returncode


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("to-sna", help="strip the MiSTer header -> .sna")
    p.add_argument("infile", type=Path)
    p.add_argument("outfile", type=Path)
    p.set_defaults(func=cmd_to_sna)

    p = sub.add_parser("to-ss", help="pad + prepend the MiSTer header -> .ss")
    p.add_argument("infile", type=Path)
    p.add_argument("outfile", type=Path)
    p.add_argument("--counter", type=int, default=1,
                   help="header change counter (default 1)")
    p.set_defaults(func=cmd_to_ss)

    p = sub.add_parser("inspect", help="decode header + embedded snapshot")
    p.add_argument("infile", type=Path)
    p.set_defaults(func=cmd_inspect)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
