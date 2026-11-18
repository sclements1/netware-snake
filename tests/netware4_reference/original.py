"""Isolated MONITOR x86 routine runner. No NetWare code executes on the host CPU."""

import struct, hashlib, os
from pathlib import Path
from unicorn import Uc, UC_ARCH_X86, UC_MODE_32, UC_HOOK_CODE
from unicorn.x86_const import *

CODE = 0x100000
DATA = 0x200000
STACK = 0x400000
STATE = 0x500000
CPU = 0x600000
STUB = 0x700000
END = 0x800000
_glyph_chain = None


class Original:
    def __init__(self, path, color=True):
        b = Path(path).read_bytes()
        self.sha = hashlib.sha256(b).hexdigest()
        if (
            self.sha
            != "0a1940dbf942abfb02db4c1690336b85454e7efd0656ea3a36cdace2f13f6c69"
        ):
            raise ValueError("Unreviewed binary SHA256")
        h = struct.unpack_from("<22I", b, 42)
        self.u = Uc(UC_ARCH_X86, UC_MODE_32)
        for base, size in [
            (CODE, 0x20000),
            (DATA, 0x10000),
            (STACK, 0x20000),
            (STATE, 0x10000),
            (CPU, 0x10000),
            (STUB, 0x10000),
            (END, 0x1000),
        ]:
            self.u.mem_map(base, size)
        self.u.mem_write(CODE, b[h[0] : h[0] + h[1]])
        self.u.mem_write(DATA, b[h[2] : h[2] + h[3]])
        self.events = []
        self.color = color
        self.calls = {}
        self.frame = [(32, 0)] * 2000
        self.glyph_values = [219, 178, 177, 176]
        self.glyph_lookup = lambda index: dict(
            zip([47, 46, 45, 44], self.glyph_values)
        )[index]
        if os.getenv("SERVER_IMAGE") or os.getenv("NWSNUT_IMAGE"):
            global _glyph_chain
            if _glyph_chain is None:
                from glyph_chain import GlyphChain

                _glyph_chain = GlyphChain(
                    os.environ["SERVER_IMAGE"], os.environ["NWSNUT_IMAGE"]
                )
            self.glyph_lookup = _glyph_chain.lookup
            self.glyph_values = [self.glyph_lookup(i) for i in [47, 46, 45, 44]]
        for r in struct.unpack_from("<" + "I" * h[10], b, h[9]):
            site = (CODE if r & 0x40000000 else DATA) + (r & 0x3FFFFFFF)
            self.put(site, self.get(site) + (CODE if r & 0x80000000 else DATA))
        p = h[11]
        for i in range(h[12]):
            n = b[p]
            p += 1
            name = b[p : p + n].decode()
            p += n
            count = struct.unpack_from("<I", b, p)[0]
            p += 4
            target = STUB + i * 16
            self.calls[target] = name
            self.u.mem_write(target, b"\xc3")
            for r in struct.unpack_from("<" + "I" * count, b, p):
                site = (CODE if r & 0x40000000 else DATA) + (r & 0x3FFFFFFF)
                self.put(
                    site, self.get(site) + target - (0 if r & 0x80000000 else site)
                )
            p += count * 4
        self.put(DATA + 0x1538, CPU + 0x1000)
        self.put(DATA + 0x1544, CPU)
        self.u.hook_add(UC_HOOK_CODE, self.hook, begin=STUB, end=STUB + 0xFFFF)

    def get(self, a):
        return struct.unpack("<I", self.u.mem_read(a, 4))[0]

    def put(self, a, v):
        self.u.mem_write(a, struct.pack("<I", v & 0xFFFFFFFF))

    def hook(self, u, a, size, data):
        name = self.calls[a]
        sp = u.reg_read(UC_X86_REG_ESP)

        def args(n):
            return [self.get(sp + 4 + i * 4) for i in range(n)]

        result = 0
        if name == "ReturnScreenType":
            a, b = args(2)
            self.put(a, 0)
            self.put(b, int(self.color))
        elif name == "NWSGetLineDrawCharacter":
            result = self.glyph_lookup(args(1)[0])
        elif name == "CSetB":
            value, dest, n = args(3)
            u.mem_write(dest, bytes([value & 255]) * n)
        elif name in ("StartScreenUpdateGroup", "EndScreenUpdateGroup"):
            self.events.append((0 if name.startswith("Start") else 1, 0, 0, 0))
        elif name == "FillScreenAreaAttribute":
            screen, y, x, w, h, color = args(6)
            assert (w, h) == (1, 1)
            self.events.append((2, x, y, color & 255))
            assert x < 80 and y < 25
            (g, _) = self.frame[y * 80 + x]
            self.frame[y * 80 + x] = (g, color & 255)
        elif name == "WriteScreenCharacter":
            screen, y, x, g = args(4)
            self.events.append((3, x, y, g & 255))
            assert x < 80 and y < 25
            _, c = self.frame[y * 80 + x]
            self.frame[y * 80 + x] = (g & 255, c)
        else:
            raise RuntimeError("Unmocked import: " + name)
        u.reg_write(UC_X86_REG_EAX, result)

    def call(self, offset, *args):
        sp = STACK + 0x1F000
        self.u.mem_write(sp, struct.pack("<" + "I" * (len(args) + 1), END, *args))
        # MONITOR uses a callee prologue pushing four registers: first argument ebp+0x14.
        self.u.reg_write(UC_X86_REG_ESP, sp)
        for r in [
            UC_X86_REG_EAX,
            UC_X86_REG_EBX,
            UC_X86_REG_ECX,
            UC_X86_REG_EDX,
            UC_X86_REG_ESI,
            UC_X86_REG_EDI,
            UC_X86_REG_EBP,
        ]:
            self.u.reg_write(r, 0)
        self.u.emu_start(CODE + offset, END, count=200000)
        if self.u.reg_read(UC_X86_REG_EIP) != END:
            raise RuntimeError("Instruction budget exceeded")
        return self.u.reg_read(UC_X86_REG_EAX)

    def init(self, i):
        a = STATE + i * 0x200
        self.put(a + 0x60, i)
        self.call(0x161F4, a)

    def step(self, i, load):
        self.events = []
        self.put(CPU + i * 4, load)
        self.call(0x15BDA, STATE + i * 0x200)
        return self.events

    def turn(self, i):
        self.call(0x15AC0, STATE + i * 0x200)

    def snapshot(self, i):
        return bytes(self.u.mem_read(STATE + i * 0x200, 0x11C))

    def rng(self):
        return bytes(self.u.mem_read(DATA + 0x1160, 118))


if __name__ == "__main__":
    import sys

    o = Original(sys.argv[1])
    print("rng", [o.call(0x15A3C) & 65535 for _ in range(8)])
    o = Original(sys.argv[1])
    o.init(0)
    for i in range(100):
        o.step(0, 0)
    print(
        "PASS: original x86 initialization and 100 idle passes; position",
        o.get(STATE + 0x6C),
        o.get(STATE + 0x70),
        "events",
        o.events[:6],
    )
