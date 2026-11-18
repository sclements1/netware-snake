#!/usr/bin/env python3
"""Static reconstruction of the MONITOR.NLM v1.76 snake core (1993).

This has no display/clock dependencies. Addresses reference NLM *code-relative*
offsets, and data-relative constants, not on-disk file offsets.

Reverse engineering research, not a runnable copy of Novell software.
"""
from dataclasses import dataclass, field
from typing import List
import argparse
import csv

MOD = 51
WIDTH, HEIGHT = 80, 25
GLYPH = [0xDB, 0xB2, 0xB1, 0xB0, 0x20]  # code/data +0x1c60
DX = [0, 1, 2, 1, 0, -1, -2, -1]  # data +0x1c65
DY = [-1, -1, 0, 1, 1, 1, 0, -1]  # data +0x1c85
RETRY_DIR = [0, 1, 1, 2, 3, 3, 4, 5, 5, 6, 7, 7]  # jump table at code +0x16c0
AUTO_TURN = [0, 0, 0, 1, 1, -1, -1, 2, -2, 3, -3]  # jump table at code +0x1630


@dataclass
class Snake:
    seed: int = 0  # determinism: substituted for DOSDateAndTime at code+0x153d
    step: int = 0
    heading: int = 2  # data +0x3530
    x: int = 38  # data +0x3514
    y: int = 12  # data +0x3510
    phase: int = 40 * 128  # data +0x352c
    cursors: List[int] = field(default_factory=lambda: [40, 30, 20, 10, 0])
    xs: List[int] = field(default_factory=lambda: [255] * 51)
    ys: List[int] = field(default_factory=lambda: [255] * 51)
    directions: List[int] = field(default_factory=lambda: [255] * 51)
    screen: List[int] = field(default_factory=lambda: [32] * 2000)
    # Instrumentation
    last_write: int = 40
    last_delta: int = 0
    last_retries: int = 0
    last_draws: int = 0
    last_erasures: int = 0
    moves: int = 0
    turn_events: int = 0

    def __post_init__(self):
        # 0x15a7-0x162f: CSetB and initial trail seed
        self.xs[40] = self.x
        self.ys[40] = self.y
        self.directions[40] = self.heading

    def _update_heading(self):
        # code +0x165c: invoked once every 40 full draw cycles
        self.seed = ((self.seed + 1) * 10013) & 0xFFFFFFFF
        choice = self.seed % 11
        self.heading = (self.heading + AUTO_TURN[choice]) % 8
        self.turn_events += 1

    def _head_move(self, cpu: int):
        # code +0x175a through +0x18e8. Retry candidates when invalid.
        attempts = 0
        original_reverse = (self.heading + 4) % 8
        while True:
            attempts += 1
            if attempts > 100000:
                raise RuntimeError("Unexpected infinite direction retry")
            proposed_x = self.x + DX[self.heading]
            proposed_y = self.y + DY[self.heading]
            if (
                0 <= proposed_x <= 78
                and 0 <= proposed_y <= 24
                and self.heading != original_reverse
            ):  # reverse of initial direction, held across retries
                break
            self.seed = ((self.seed + 1) * 10013) & 0xFFFFFFFF
            random_index = (self.seed % 47) % 12
            self.heading = RETRY_DIR[random_index]
        self.last_retries = attempts - 1
        self.x, self.y = proposed_x, proposed_y
        self.moves += 1
        # eax=(1280 // (9*load//100+1) + phase) >>7; edx=eax%51
        self.last_delta = 1280 // ((9 * cpu) // 100 + 1)
        idx = ((self.last_delta + self.phase) >> 7) % 51
        self.last_write = idx
        self.xs[idx] = self.x
        self.ys[idx] = self.y
        self.directions[idx] = self.heading

    def update(self, cpu: int):
        """One complete draw/update pass; deliberately NOT assigned a wall-clock duration."""
        if not 0 <= cpu <= 100:
            raise ValueError(cpu)
        self.last_draws = 0
        self.last_erasures = 0
        # Stages 4 to 0. code +0x16f9-0x194a
        for stage in (4, 3, 2, 1, 0):
            cursor = self.cursors[stage]
            if self.xs[cursor] < 81:  # code +0x1714 (sentinel FF excluded)
                x, y = self.xs[cursor], self.ys[cursor]
                base = y * 80 + x
                # Original only writes character bytes at two consecutive cells;
                # byte-level attrs in original screen remain unchanged.
                if 0 <= base < 1999:
                    self.screen[base] = GLYPH[stage]
                    self.screen[base + 1] = GLYPH[stage]
                    if stage == 4:
                        self.last_erasures += 2
                    else:
                        self.last_draws += 2
                if stage == 0:
                    self._head_move(cpu)
                if stage == 4:
                    self.xs[cursor] = 255
                    self.ys[cursor] = 255
            # very important: actual first-stage head move is only in valid branch
            # when a frame has stage 0 sentinel, 0x175a is never executed!
            if stage == 0:
                self.phase = (self.phase + 128) % (51 * 128)
                self.cursors[0] = self.phase >> 7
            else:
                self.cursors[stage] = (cursor + 1) % 51
        self.step += 1
        # 0x1322-0x133b: the draw call is followed by a heading change on
        # every 40th frame (and followed by DelayMyself(1, tag) every frame).
        if self.step % 40 == 0:
            self._update_heading()
        return self

    @property
    def occupied(self):
        return sum(v != 32 for v in self.screen)

    @property
    def shaded(self):
        return {k: sum(v == k for v in self.screen) for k in GLYPH}

    def line(self):
        glyph = {32: " ", 0xDB: "█", 0xB2: "▓", 0xB1: "▒", 0xB0: "░"}
        return "\n".join(
            "".join(glyph[c] for c in self.screen[y * 80 : (y + 1) * 80])
            for y in range(25)
        )


def main():
    a = argparse.ArgumentParser()
    a.add_argument("--loads", default="0,25,50,75,100")
    a.add_argument("--frames", type=int, default=400)
    a.add_argument("--seed", type=lambda x: int(x, 0), default=0)
    a.add_argument("--csv")
    a.add_argument("--show", type=int)
    args = a.parse_args()
    data = []
    for cpu in [int(v) for v in args.loads.split(",")]:
        s = Snake(seed=args.seed)
        for f in range(1, args.frames + 1):
            s.update(cpu)
            data.append(
                dict(
                    cpu=cpu,
                    frame=f,
                    occupied=s.occupied,
                    heads=s.shaded[0xDB],
                    shade_heavy=s.shaded[0xB2],
                    shade_medium=s.shaded[0xB1],
                    shade_light=s.shaded[0xB0],
                    x=s.x,
                    y=s.y,
                    heading=s.heading,
                    history_write=s.last_write,
                    head_cursor=s.cursors[0],
                    d=s.last_delta,
                    attempts=s.last_retries,
                    moves=s.moves,
                )
            )
        if args.show == cpu:
            print("\n", cpu, "\n", s.line())
        warm = [r["occupied"] for r in data if r["cpu"] == cpu and r["frame"] > 100]
        print(
            f"U={cpu:3}% | moves={s.moves:3}/{args.frames}, occupied final={s.occupied:4}, post-100 average={sum(warm)/len(warm):7.2f}, range=({min(warm)}, {max(warm)}), last pos=({s.x},{s.y}), offset={s.last_delta//128} slots"
        )
    if args.csv:
        with open(args.csv, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=data[0])
            w.writeheader()
            w.writerows(data)


if __name__ == "__main__":
    main()
