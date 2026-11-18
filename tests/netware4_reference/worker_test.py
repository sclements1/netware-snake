from original import Original, DATA, STATE
import sys, ctypes as C

lib = C.CDLL(sys.argv[2])
P = C.c_void_p
U = C.c_uint
B = C.c_uint8
CB = C.CFUNCTYPE(None, P, U, U, U, U)
lib.nw4_create.restype = P
for name, args in {
    "nw4_destroy": [P],
    "nw4_init": [P, U, C.c_int, P],
    "nw4_tick": [P, U, U, CB, P],
    "nw4_state": [P, U, P],
    "nw4_random_state": [P, P],
    "nw4_characters": [P],
    "nw4_attributes": [P],
}.items():
    getattr(lib, name).argtypes = args
lib.nw4_characters.restype = P
lib.nw4_attributes.restype = P


class Worker(Original):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.delays = 0
        self.updates = 0
        self.first = None
        self.stop_at = 0
        self.destroyed = []

    def hook(self, u, a, size, data):
        name = self.calls[a]
        if name in ("CPSemaphore", "CVSemaphore", "DelayMyself", "CDestroyProcess"):
            from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_ESP

            sp = u.reg_read(UC_X86_REG_ESP)
            if name == "DelayMyself":
                assert self.get(sp + 4) == 1
                self.delays += 1
                if self.updates >= self.stop_at:
                    self.put(DATA + 0x3F48, 1)
            elif name == "CDestroyProcess":
                self.destroyed.append(self.get(sp + 4))
            u.reg_write(UC_X86_REG_EAX, 0)
        else:
            if name == "StartScreenUpdateGroup":
                self.updates += 1
                if self.first is None:
                    self.first = self.delays
            super().hook(u, a, size, data)


for p in [0, 1, 15, 31]:
    o = Worker(sys.argv[1])
    w = lib.nw4_create()
    glyph = (B * 5)(*o.glyph_values, 32)
    for i in range(p + 1):
        o.init(i)
        assert lib.nw4_init(w, i, True, glyph)
    o.stop_at = 80
    o.call(0x163E3, STATE + p * 0x200)
    events = []
    cb = CB(lambda ctx, k, x, y, v: events.append((k, x, y, v)))
    for j in range(80):
        assert lib.nw4_tick(w, p, 0, cb, None)
    image = (B * 284)()
    assert lib.nw4_state(w, p, image)
    assert bytes(image) == o.snapshot(p)
    rng = (B * 118)()
    lib.nw4_random_state(w, rng)
    assert bytes(rng) == o.rng()
    assert events == o.events
    assert C.string_at(lib.nw4_characters(w), 2000) == bytes(g for g, c in o.frame)
    assert C.string_at(lib.nw4_attributes(w), 2000) == bytes(c for g, c in o.frame)
    print(
        "processor",
        p,
        "first update after",
        o.first,
        "delay calls; updates",
        o.updates,
        "delays",
        o.delays,
        "state/events/framebuffer match C",
    )
    assert (
        o.first == 4 * p
        and o.updates == 80
        and o.delays == 4 * p + 80
        and len(o.destroyed) == 1
    )
    lib.nw4_destroy(w)
print(
    "PASS original worker startup/loop delay placement, exit, and portable engine parity"
)
