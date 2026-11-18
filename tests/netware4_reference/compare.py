"""Differentially compare portable C with original MONITOR x86 instructions."""

import ctypes as C, sys, random, time, struct, json, os
from pathlib import Path
from original import Original, STATE, DATA

lib = C.CDLL(sys.argv[2])
P = C.c_void_p
U = C.c_uint
B = C.c_uint8
CB = C.CFUNCTYPE(None, P, U, U, U, U)
lib.nw4_create.restype = P
for name, args in {
    "nw4_destroy": [P],
    "nw4_reset_colors": [P],
    "nw4_init": [P, U, C.c_int, P],
    "nw4_tick": [P, U, U, CB, P],
    "nw4_state": [P, U, P],
    "nw4_random_state": [P, P],
    "nw4_random": [P],
    "nw4_characters": [P],
    "nw4_attributes": [P],
    "nw4_slot_lead": [U],
}.items():
    getattr(lib, name).argtypes = args
lib.nw4_random.restype = C.c_uint16
lib.nw4_characters.restype = P
lib.nw4_attributes.restype = P
binary = sys.argv[1]
results = []
total = 0
t0 = time.monotonic()


class Pair:
    def __init__(self, n=1, color=True):
        self.o = Original(binary, color)
        self.w = lib.nw4_create()
        assert self.w
        self.n = n
        self.counts = [0] * 32
        self.events = []
        self.cb = CB(lambda ctx, k, x, y, v: self.events.append((k, x, y, v)))
        glyph = (B * 5)(*self.o.glyph_values, 32)
        for i in range(n):
            self.o.init(i)
            assert lib.nw4_init(self.w, i, color, glyph)
            self.check(i)

    def check(self, i):
        a = (B * 284)()
        assert lib.nw4_state(self.w, i, a)
        raw = bytes(a)
        expected = self.o.snapshot(i)
        assert raw == expected, (
            "state",
            i,
            [(hex(j), x, y) for j, (x, y) in enumerate(zip(raw, expected)) if x != y][
                :12
            ],
        )
        a = (B * 118)()
        lib.nw4_random_state(self.w, a)
        assert bytes(a) == self.o.rng(), ("rng state", i)

    def step(self, i, u):
        global total
        expected = list(self.o.step(i, u))
        self.counts[i] += 1
        if self.counts[i] % 40 == 0:
            self.o.turn(i)
        self.events = []
        assert lib.nw4_tick(self.w, i, u, self.cb, None)
        assert self.events == expected, ("events", total, i, u, self.events, expected)
        self.check(i)
        chars = bytes(g for g, c in self.o.frame)
        attrs = bytes(c for g, c in self.o.frame)
        assert C.string_at(lib.nw4_characters(self.w), 2000) == chars, (
            "character framebuffer",
            total,
        )
        assert C.string_at(lib.nw4_attributes(self.w), 2000) == attrs, (
            "attribute framebuffer",
            total,
        )
        total += 1

    def close(self):
        lib.nw4_destroy(self.w)


def run(name, f):
    before = total
    start = time.monotonic()
    f()
    row = {
        "case": name,
        "passes": total - before,
        "seconds": round(time.monotonic() - start, 3),
    }
    results.append(row)
    print("PASS", row, flush=True)


def rng_test():
    o = Original(binary)
    w = lib.nw4_create()
    for i in range(20000):
        assert (o.call(0x15A3C) & 65535) == lib.nw4_random(w), ("rng output", i)
    a = (B * 118)()
    lib.nw4_random_state(w, a)
    assert bytes(a) == o.rng()
    lib.nw4_destroy(w)


def load_test():
    for u in range(101):
        p = Pair()
        for j in range(160):
            p.step(0, u)
        p.close()


def long_test():
    for u in [0, 12, 23, 34, 56, 100]:
        p = Pair()
        for j in range(1200):
            p.step(0, u)
        p.close()


def multi_test(n, color=True):
    p = Pair(n, color)
    r = random.Random(421)
    for j in range(160):
        order = list(range(n))
        r.shuffle(order)
        for i in order:
            p.step(i, r.randrange(101))
    p.close()


def restart_test():
    p = Pair(4)
    for j in range(100):
        for i in range(4):
            p.step(i, (j * 13 + i * 7) % 101)
    # New activation: palette resets but the shared random table carries over.
    # Original allocates fresh state; clear its scratch objects, preserve module data.
    p.o.put(DATA + 0x3F50, 0)
    lib.nw4_reset_colors(p.w)
    p.o.u.mem_write(STATE, bytes(32 * 0x200))
    glyph = (B * 5)(*p.o.glyph_values, 32)
    for i in range(4):
        p.o.init(i)
        assert lib.nw4_init(p.w, i, True, glyph)
        p.counts[i] = 0
        p.check(i)
    for j in range(100):
        for i in range(4):
            p.step(i, 100 if j < 50 else 0)
    p.close()


run("20000 RNG outputs and complete random-state parity", rng_test)
run("all percentage inputs 0..100, 160 passes each", load_test)
run("long stable runs across all five bands and 100%", long_test)
for n in [1, 2, 4, 16, 32]:
    run(
        f"{n} snakes, shuffled scheduling and changing per-CPU loads",
        lambda n=n: multi_test(n),
    )
run("32 snakes, alternate screen-type branch", lambda: multi_test(32, False))
run("restart, palette reset and RNG continuity", restart_test)
print("PASS total", total, "passes;", round(time.monotonic() - t0, 2), "seconds")
Path(sys.argv[3]).write_text(
    json.dumps(
        {
            "status": "PASS",
            "total_passes": total,
            "rng_outputs": 20000,
            "results": results,
            "seconds": round(time.monotonic() - t0, 3),
            "comparison": [
                "284-byte snake image after each pass",
                "shared 118-byte RNG state after each pass",
                "ordered attribute and character write events",
                "entire 80x25 character and attribute framebuffer",
            ],
            "glyph_source": (
                "actual SERVER table-copy and NWSNUT lookup routines"
                if os.getenv("SERVER_IMAGE")
                else "mocked glyph constants"
            ),
            "mocked_dependencies": [
                "ReturnScreenType outputs",
                "screen service effects",
            ]
            + ([] if os.getenv("SERVER_IMAGE") else ["glyph constants"]),
            "excluded": [
                "NetWare timer delay units",
                "process startup/allocation path",
                "real scheduler interleaving",
                "packed-to-unpacked equivalence",
            ],
        },
        indent=2,
    )
    + "\n"
)
