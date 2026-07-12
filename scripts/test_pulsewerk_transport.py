#!/usr/bin/env python3
"""Focused transport regression checks for PulseWerk v4.

The scenario model documents the intended host-block behaviour. Source-contract
checks ensure the JSFX retains the state/order required to implement it. Final
audio/MIDI verification still requires REAPER.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EFFECT = ROOT / "Effects" / "PulseWerk_v4.jsfx"
STEP_BEATS = 0.25
EPSILON = 0.000001


def scheduled_steps(block_start: float, block_end: float, origin: float):
    schedule_start = max(block_start, origin)
    step_index = int((schedule_start / STEP_BEATS) + EPSILON)
    step_time = step_index * STEP_BEATS
    if step_time < schedule_start - EPSILON:
        step_time += STEP_BEATS
    result = []
    while step_time < block_end - EPSILON:
        result.append(int(((step_time - origin) / STEP_BEATS) + EPSILON))
        step_time += STEP_BEATS
    return result


class TransportClock:
    def __init__(self):
        self.stopped_cursor = 0.0
        self.origin = 0.0

    def stop_at(self, cursor: float):
        self.stopped_cursor = cursor
        return (0, 0)

    def start(self, block_start: float, block_end: float):
        self.origin = self.stopped_cursor
        return scheduled_steps(block_start, block_end, self.origin)

    def continue_block(self, block_start: float, block_end: float):
        return scheduled_steps(block_start, block_end, self.origin)

    def reanchor(self, block_start: float, block_end: float):
        self.origin = block_start
        return scheduled_steps(block_start, block_end, self.origin)


def assert_scenarios() -> None:
    clock = TransportClock()
    assert clock.stop_at(160.0) == (0, 0)
    assert clock.start(160.0, 160.1) == [0]

    clock.stop_at(160.01)
    assert clock.start(160.01, 160.3) == [0]

    # Automation/pre-roll may make the first processing block precede the
    # stopped edit cursor. Nothing may fire before that captured origin.
    clock.stop_at(160.0)
    assert clock.start(159.75, 160.0) == []
    assert clock.continue_block(160.0, 160.1) == [0]

    # Continuous half-open blocks emit each boundary exactly once.
    clock.stop_at(160.0)
    first = clock.start(160.0, 160.25)
    second = clock.continue_block(160.25, 160.5)
    assert first + second == [0, 1]

    # An in-play seek begins a fresh cycle from its first block.
    assert clock.reanchor(200.0, 200.1) == [0]

    # The explicit reset trigger uses the same re-anchor operation.
    assert clock.reanchor(240.0, 240.1) == [0]

    # Stopped preview is always the beginning of a fresh cycle.
    assert clock.stop_at(241.37) == (0, 0)


def assert_source_contract() -> None:
    source = EFFECT.read_text()
    capture = source.index("stopped_cursor_beats = block_start_beats;")
    reset = source.index("reset_cycle_to_beats(stopped_cursor_beats);")
    display = source.index(
        "transport_step_abs = relative_step_index_for_beats(block_start_beats);"
    )
    schedule = source.index(
        "schedule_start_beats = max(block_start_beats, cycle_origin_beats);"
    )

    assert capture < reset < display < schedule
    assert "file_var(0, serialized_cycle_origin_legacy);" in source
    assert "file_var(0, cycle_origin_beats);" not in source
    assert "current_step_in_bar = 0;\n);\n\nui_audition_pending" in source


if __name__ == "__main__":
    assert_scenarios()
    assert_source_contract()
    print("PulseWerk transport regression checks passed.")
