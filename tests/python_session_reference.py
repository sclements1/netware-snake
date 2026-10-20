"""Portable simulation session and an optional *display-only* overlap compositor.

The only source of snake motion/history/shading is netware312_reference.Snake,
which is an unchanged copy of the binary-derived v1.76 research core.
"""
from dataclasses import dataclass
from typing import Dict, Tuple

from python_reference import Snake, GLYPH, WIDTH, HEIGHT

SIM_HZ = 18.2  # VM video corroborates ~18.2 visible passes/s at high load
BANDS = ((0, 11, 10), (12, 22, 5), (23, 33, 3), (34, 55, 2), (56, 100, 1))
BAND_TARGETS = (5, 17, 28, 44, 75, 44, 28, 17, 5)


def band(cpu):
    if not 0 <= cpu <= 100:
        raise ValueError('CPU utilization outside 0-100')
    for index, (lo, hi, spacing) in enumerate(BANDS, start=1):
        if lo <= cpu <= hi:
            return index, spacing
    raise AssertionError('No CPU band')


@dataclass(frozen=True)
class PaintEvent:
    stage: int
    slot: int
    generation: int
    x: int
    y: int


class SnakeSession:
    """A faithful state engine plus an optional overlap-aware raster projection.

    To prove that display experiments don't alter the original state machine,
    this class delegates all state transitions to the unmodified Snake.update().
    Pre-pass snapshots expose paint events without patching its logic.
    """
    def __init__(self, seed=0):
        self.core = Snake(seed=seed)
        self.cpu = 0
        self.generations = [None] * 51
        self.generations[40] = 1  # the original seeded coordinate
        self.next_generation = 2
        # generation -> (x, y, last visible stage)
        self.active: Dict[int, Tuple[int, int, int]] = {}
        self.enhanced_screen = [32] * (WIDTH * HEIGHT)
        self.events = []
        self.crossing_erase_events = 0
        self.raw_visible_updates = 0
        self.last_screen_changed = False
        self.last_head_moved = False
        self.last_cpu_band = band(0)[0]

    def advance(self, cpu):
        cpu = int(cpu)
        self.last_cpu_band, _ = band(cpu)
        self.cpu = cpu
        self.events = []
        # The original draws stages IN THIS ORDER, before moving stage 0.
        for stage in (4, 3, 2, 1, 0):
            slot = self.core.cursors[stage]
            if self.core.xs[slot] < 81:
                gen = self.generations[slot]
                assert gen is not None, (stage, slot)
                self.events.append(PaintEvent(stage, slot, gen,
                                              self.core.xs[slot], self.core.ys[slot]))
        old_moves = self.core.moves
        old_screen = self.core.screen[:]
        self.core.update(cpu)  # binary-derived state transition: source of truth
        self.last_head_moved = self.core.moves != old_moves
        self.last_screen_changed = old_screen != self.core.screen
        if self.last_screen_changed:
            self.raw_visible_updates += 1
        # Process the same paint events to maintain an alternative, non-destructive
        # compositor. This NEVER writes back to core.screen or snake history.
        for event in self.events:
            if event.stage == 4:
                # Head/tail crossing: old tail erases a cell still occupied by
                # a more recently generated live segment in faithful mode.
                for gen, (x, y, stage) in self.active.items():
                    if gen > event.generation and y == event.y and (abs(x-event.x) <= 1):
                        self.crossing_erase_events += 1
                        break
                self.active.pop(event.generation, None)
                self.generations[event.slot] = None
            else:
                self.active[event.generation] = (event.x, event.y, event.stage)
        if self.last_head_moved:
            slot = self.core.last_write
            previous_gen = self.generations[slot]
            if previous_gen is not None:
                self.active.pop(previous_gen, None)
            self.generations[slot] = self.next_generation
            self.next_generation += 1
        self._compose_enhanced()
        return self

    def _compose_enhanced(self):
        result = [32] * (WIDTH * HEIGHT)
        # Highest generation wins; older tail cannot punch holes in a newer head.
        for _, (x, y, stage) in sorted(self.active.items()):
            glyph = GLYPH[stage]
            if glyph == 32:
                continue
            pos = y * WIDTH + x
            result[pos] = glyph
            result[pos+1] = glyph
        self.enhanced_screen = result

    def screen(self, mode='faithful'):
        if mode == 'faithful':
            return self.core.screen
        if mode == 'overlap-aware':
            return self.enhanced_screen
        raise ValueError(f'Unknown display mode {mode!r}')

    def metrics(self, mode='faithful'):
        screen = self.screen(mode)
        index, spacing = band(self.cpu)
        return {
            'pass': self.core.step,
            'elapsed_sim_s': round(self.core.step / SIM_HZ, 4),
            'cpu_percent': self.cpu,
            'band': index,
            'passes_per_move': spacing,
            'head_moves_total': self.core.moves,
            'head_moved_this_pass': int(self.last_head_moved),
            'raw_frame_changed': int(self.last_screen_changed),
            'raw_visible_updates_total': self.raw_visible_updates,
            'occupied_cells': sum(v != 32 for v in screen),
            'head_x': self.core.x,
            'head_y': self.core.y,
            'heading': self.core.heading,
            'history_write_slot': self.core.last_write,
            'erase_crossings_total': self.crossing_erase_events,
            'display_mode': mode,
        }
