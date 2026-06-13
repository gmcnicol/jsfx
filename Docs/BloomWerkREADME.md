# BloomWerk

BloomWerk is a deterministic harmonic-cloud JSFX effect. It is designed as a send effect or instrument that turns audio, MIDI, or both into blooming resonators and grains.

## Signal Flow

BloomWerk keeps one shared 12-bin harmonic field.

- **Audio Mode** analyses stereo input into pitch-class energy bins and uses that field to excite the bloom.
- **MIDI Mode** maps MIDI note events into the same 12 pitch classes. Velocity controls how strongly each pitch class is excited.
- **Hybrid Mode** keeps both paths active: audio provides the captured source material and MIDI provides timing plus harmonic steering.

The field drives a 12-voice tuned resonator bank, a Vines coupling network, and a deterministic grain cloud. The grain engine captures the input buffer and chooses pitch offsets from the active harmonic field rather than from pure random pitch shifts.

## Runtime Boundaries

BloomWerk follows the same separation rule as the refined OvumTone editor:

- `@block` only captures MIDI into a small queue and optionally passes MIDI through.
- `@sample` owns audio analysis, field updates, resonators, grains, smoothing, reset, freeze, and output.
- `@gfx` never reads the live DSP arrays. Audio publishes throttled monitor snapshots, and the graphics view draws only those snapshots through one cache image and one final `gfx_blit()`.

This keeps graphics redraws from mutating audio state and keeps sample processing from doing panel work.

## Controls

The core v1 controls are **Mode**, **Root**, **Scale**, **Bloom**, **Memory**, **Vines**, **Chaos**, **Drift**, **Freeze**, **Wet**, and **Output**. Additional field and grain controls expose audio/MIDI balance, harmonic pull, grain amount, grain size, grain density, pitch spread, feedback, damping, width, seed, MIDI thru, and the debug monitor.

Fixed input with the same seed and settings is intended to produce repeatable output. The Reset slider clears the field, resonator, grain, detector, and capture state.

## Routing With MIDI Generators

To use WaterSplash or another MIDI generator as a BloomWerk control source in REAPER:

1. Put `Effects/BloomWerk_v1.jsfx` on an audio track that receives or plays source audio.
2. Put `Effects/WaterSplash2`, `Effects/WaterSplash_ModeGravity.jsfx`, `Effects/MIDI_IsLife`, or another MIDI generator on a separate track.
3. Create a send from the MIDI generator track to the BloomWerk track and enable MIDI on the send.
4. Set BloomWerk to **MIDI** or **Hybrid** mode.

In MIDI mode, the generator's notes directly excite the harmonic field. In Hybrid mode, those same notes steer timing and harmony while the BloomWerk audio input supplies the grain material.

Existing MIDI generator behavior is unchanged. BloomWerk only listens to incoming MIDI and optionally passes it through when MIDI Thru is enabled.

## Reused Ideas

- `Effects/OpenScaleEQ_v1.jsfx` provides the reference for FFT-derived chroma energy and scale-aware pitch-class handling.
- `Effects/Life_Grain` provides the reference for deterministic captured-input grain playback.
- `Effects/WaterSplash2`, `Effects/WaterSplash_ModeGravity.jsfx`, and `Effects/MIDI_IsLife` provide the MIDI droplet/event control model.

BloomWerk v1 prioritizes musical, controllable behavior over deep complexity. The implementation keeps all ticketed modes in one effect so audio, MIDI, hybrid, resonator, grain, and performance controls share the same field state.
