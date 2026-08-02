#!/usr/bin/env python3
"""Focused transport regression checks for PulseWerk v4."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EFFECT = ROOT / "Effects" / "PulseWerk_v4.jsfx"
STEP_BEATS = 0.25
EPSILON = 0.000001


def phase(beat: float, origin: float, cycle_bars: int = 8):
    step = int(((beat - origin) / STEP_BEATS) + EPSILON)
    cycle_steps = cycle_bars * 16
    return step % cycle_steps, max(1, step // cycle_steps + 1)


def scheduled_steps(block_start: float, block_end: float, origin: float):
    step_index = int(((block_start - origin) / STEP_BEATS) + EPSILON)
    step_time = origin + step_index * STEP_BEATS
    if step_time < block_start - EPSILON:
        step_index += 1
        step_time += STEP_BEATS
    result = []
    while step_time < block_end - EPSILON:
        result.append(step_index)
        step_index += 1
        step_time += STEP_BEATS
    return result


class TransportClock:
    def __init__(self):
        self.stopped_cursor = 0.0
        self.origin = 0.0
        self.reset_next_playback = False

    def stop_at(self, cursor: float):
        self.stopped_cursor = cursor
        self.origin = 0.0
        return phase(cursor, self.origin)

    def arm_reset(self):
        self.reset_next_playback = True

    def start(self, block_start: float, block_end: float):
        if self.reset_next_playback:
            self.origin = self.stopped_cursor
            self.reset_next_playback = False
        else:
            self.origin = 0.0
        return scheduled_steps(block_start, block_end, self.origin)

    def continue_block(self, block_start: float, block_end: float):
        return scheduled_steps(block_start, block_end, self.origin)


def assert_scenarios() -> None:
    clock = TransportClock()

    # pulse.RPP: bar 41.1 is beat 160, cycle 6 of an eight-bar cycle.
    assert clock.stop_at(160.0) == (0, 6)
    assert clock.start(160.0, 160.1) == [640]

    # Starting elsewhere follows project time instead of restarting the cycle.
    clock.stop_at(164.25)
    assert clock.start(164.25, 164.35) == [657]
    assert phase(164.25, clock.origin) == (17, 6)

    # Reset is latched while stopped and affects one playback only.
    clock.stop_at(164.25)
    clock.arm_reset()
    assert clock.start(164.25, 164.35) == [0]
    assert clock.continue_block(164.5, 164.6) == [1]
    assert phase(164.5, clock.origin) == (1, 1)

    # Seeking during reset playback keeps its chosen origin deterministic.
    assert clock.continue_block(168.25, 168.35) == [16]
    assert phase(168.25, clock.origin) == (16, 1)

    clock.stop_at(164.25)
    assert clock.start(164.25, 164.35) == [657]


def assert_source_contract() -> None:
    source = EFFECT.read_text()
    assert "reset_next_playback_pending = 1;" in source
    assert "reset_next_playback_pending ? (" in source
    assert "cycle_origin_beats = 0;" in source
    assert "step_time = cycle_origin_beats + step_index * STEP_BEATS;" in source
    assert "current_cycle_number = max(1, floor(transport_step_abs / cycle_steps) + 1);" in source
    header = source[source.index('sprintf(#header_pos'):]
    assert 'current_cycle_number' in header.split(';', 1)[0]
    assert "file_var(0, serialized_cycle_origin_legacy);" in source
    assert "file_var(0, cycle_origin_beats);" not in source


if __name__ == "__main__":
    assert_scenarios()
    assert_source_contract()
    print("PulseWerk transport regression checks passed.")
