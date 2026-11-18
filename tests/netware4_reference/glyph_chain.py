"""Run actual SERVER GetOSLineDrawCharTable -> actual NWSNUT lookup."""

import struct, hashlib, json
from pathlib import Path
from unicorn import Uc, UC_ARCH_X86, UC_MODE_32
from unicorn.x86_const import UC_X86_REG_ESP, UC_X86_REG_EAX, UC_X86_REG_EIP


class GlyphChain:
    def __init__(self, server, nwsnut):
        self.u = Uc(UC_ARCH_X86, UC_MODE_32)
        self.images = []
        self.u.mem_map(0x700000, 0x10000)
        self.u.mem_map(0x800000, 4096)
        k, kd, kh = self.load(
            server,
            0x100000,
            0x300000,
            "66b204a974efc5019946d238e74aba61f8c99db78364c6b86bb273c1f2748546",
        )
        n, nd, nh = self.load(
            nwsnut,
            0x500000,
            0x600000,
            "eafbf1f29be65514bcf62f20e5932ad246b4e641627ff0e03472b1fbc81c7988",
        )
        # Find kernel's internal publication record from name and paired code fixups.
        name = b"GetOSLineDrawCharTable"
        start = kd.find(bytes([len(name)]) + name + b"\0")
        assert start >= 0
        positions = [
            i for i in range(len(kd) - 4) if kd[i : i + 4] == struct.pack("<I", start)
        ]
        rel = set(struct.unpack_from("<" + "I" * kh[10], k, kh[9]))
        entries = []
        for p in positions:
            a = struct.unpack_from("<I", kd, p - 4)[0]
            b = struct.unpack_from("<I", kd, p + 8)[0]
            if (
                a == b
                and (0x80000000 | (p - 4)) in rel
                and (0x80000000 | (p + 8)) in rel
            ):
                entries.append((p, a))
        assert len(entries) == 1
        record, self.copy_entry = entries[0]
        p = nh[13]
        exports = {}
        for _ in range(nh[14]):
            length = n[p]
            p += 1
            s = n[p : p + length].decode("latin1")
            p += length
            v = struct.unpack_from("<I", n, p)[0]
            p += 4
            exports[s] = v
        self.lookup_entry = exports["NWSGetLineDrawCharacter"] & 0x7FFFFFFF
        # Library initialization calls kernel table copy with its own table address.
        self.call(0x100000 + self.copy_entry, 0x600000 + 0x6C0)
        self.table = bytes(self.u.mem_read(0x600000 + 0x6C0, 48))
        self.record = {
            "kernel_publication_name_data_offset": hex(start),
            "publication_name_pointer_data_offset": hex(record),
            "kernel_copy_entry": hex(self.copy_entry),
            "nwsnut_lookup_entry": hex(self.lookup_entry),
            "copied_table": list(self.table),
            "images": self.images,
        }

    def load(self, path, cb, db, expected):
        b = Path(path).read_bytes()
        sha = hashlib.sha256(b).hexdigest()
        if sha != expected:
            raise ValueError(("Unreviewed module", str(path), sha, expected))
        h = struct.unpack_from("<22I", b, 42)
        data = b[h[2] : h[2] + h[3]]
        for a, size in [(cb, h[1]), (db, h[3] + h[4])]:
            self.u.mem_map(a, (size + 4095) & ~4095)
        self.u.mem_write(cb, b[h[0] : h[0] + h[1]])
        self.u.mem_write(db, data)
        for r in struct.unpack_from("<" + "I" * h[10], b, h[9]):
            site = (cb if r & 0x40000000 else db) + (r & 0x3FFFFFFF)
            v = struct.unpack("<I", self.u.mem_read(site, 4))[0]
            self.u.mem_write(
                site,
                struct.pack("<I", (v + (cb if r & 0x80000000 else db)) & 0xFFFFFFFF),
            )
        self.images.append(
            {
                "name": Path(path).name,
                "sha256": sha,
                "code_file_offset": h[0],
                "data_file_offset": h[2],
            }
        )
        return b, data, h

    def call(self, entry, *args):
        sp = 0x70F000
        self.u.mem_write(sp, struct.pack("<" + "I" * (len(args) + 1), 0x800000, *args))
        self.u.reg_write(UC_X86_REG_ESP, sp)
        self.u.emu_start(entry, 0x800000, count=1000)
        assert self.u.reg_read(UC_X86_REG_EIP) == 0x800000
        return self.u.reg_read(UC_X86_REG_EAX)

    def lookup(self, index):
        return self.call(0x500000 + self.lookup_entry, index & 0xFFFFFFFF)


if __name__ == "__main__":
    import sys

    g = GlyphChain(sys.argv[1], sys.argv[2])
    values = [g.lookup(i) for i in [47, 46, 45, 44]]
    assert values == [219, 178, 177, 176]
    for i in range(48):
        assert g.lookup(i) == g.table[i]
    for i in [48, 49, 0xFFFFFFFF, 0x80000000]:
        assert g.lookup(i) == 0
    g.record.update(
        monitor_indices=[47, 46, 45, 44],
        returned_bytes_hex=[hex(v) for v in values],
        tests=52,
        status="PASS",
    )
    Path(sys.argv[3]).write_text(json.dumps(g.record, indent=2) + "\n")
    print(
        "PASS actual kernel copy + NWSNUT lookup:",
        [hex(v) for v in values],
        "; 52 legal/boundary checks",
    )
