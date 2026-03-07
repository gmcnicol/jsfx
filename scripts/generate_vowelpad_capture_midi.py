#!/usr/bin/env python3
"""Generate a 120 BPM capture MIDI for VowelPad sampling.

Sequence design:
- PPQ: 480
- Tempo: 120 BPM
- Notes: C2..C6 every 3 semitones
- Each note length: 20 beats (10 seconds)
- Gap between notes: 4 beats (2 seconds)
- Pre-roll: 4 beats
"""

from __future__ import annotations

from pathlib import Path
import struct


PPQ = 480
BPM = 120
TEMPO_US_PER_QN = int(60_000_000 / BPM)
CHANNEL = 0
VELOCITY = 100
NOTE_START = 36
NOTE_END = 84
NOTE_STEP = 3
PRE_ROLL_BEATS = 4
NOTE_LENGTH_BEATS = 20
GAP_BEATS = 4


def var_len(value: int) -> bytes:
    parts = [value & 0x7F]
    value >>= 7
    while value:
        parts.append((value & 0x7F) | 0x80)
        value >>= 7
    return bytes(reversed(parts))


def midi_event(delta: int, payload: bytes) -> bytes:
    return var_len(delta) + payload


def build_track() -> bytes:
    events = bytearray()

    # Meta: track name and tempo/time signature at delta 0.
    events += midi_event(0, b"\xFF\x03" + bytes([len("VowelPad Capture 120 BPM")]) + b"VowelPad Capture 120 BPM")
    events += midi_event(0, b"\xFF\x51\x03" + struct.pack(">I", TEMPO_US_PER_QN)[1:])
    events += midi_event(0, b"\xFF\x58\x04\x04\x02\x18\x08")  # 4/4

    tick = PRE_ROLL_BEATS * PPQ
    last_tick = 0

    for note in range(NOTE_START, NOTE_END + 1, NOTE_STEP):
        note_on_tick = tick
        note_off_tick = tick + (NOTE_LENGTH_BEATS * PPQ)

        events += midi_event(note_on_tick - last_tick, bytes([0x90 | CHANNEL, note, VELOCITY]))
        last_tick = note_on_tick

        events += midi_event(note_off_tick - last_tick, bytes([0x80 | CHANNEL, note, 0]))
        last_tick = note_off_tick

        tick = note_off_tick + (GAP_BEATS * PPQ)

    # End of track.
    events += midi_event(0, b"\xFF\x2F\x00")
    return bytes(events)


def write_midi(path: Path) -> None:
    track_data = build_track()

    header = bytearray()
    header += b"MThd"
    header += struct.pack(">IHHH", 6, 0, 1, PPQ)  # format 0, 1 track

    track_chunk = bytearray()
    track_chunk += b"MTrk"
    track_chunk += struct.pack(">I", len(track_data))
    track_chunk += track_data

    path.write_bytes(bytes(header + track_chunk))


if __name__ == "__main__":
    output = Path(__file__).resolve().parents[1] / "Data" / "midi" / "VowelPad_capture_120bpm.mid"
    write_midi(output)
    notes = list(range(NOTE_START, NOTE_END + 1, NOTE_STEP))
    total_beats = PRE_ROLL_BEATS + len(notes) * (NOTE_LENGTH_BEATS + GAP_BEATS)
    total_seconds = total_beats * (60 / BPM)
    print(f"wrote: {output}")
    print(f"notes: {len(notes)} ({notes[0]}..{notes[-1]} step {NOTE_STEP})")
    print(f"total duration: {total_seconds:.1f}s")
