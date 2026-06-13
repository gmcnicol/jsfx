# JSFX
JSFX Scripts that I've written for Cockos Reaper.

# Included Effects
* `ccinterpolate` a JSFX Reimanging of Babyaudio's Transit2
* `CrescendoWerk_v1.jsfx` structured post-rock / post-metal MIDI drum generator with Patient Pulse, Procession / Tension, and Weight / Tom Motion layers plus a form-aware `@gfx` editor.
* `DanseWerk_v1.jsfx` structured EBM / industrial MIDI drum generator with Command / Contamination / Punishment layers and a form-aware `@gfx` editor.
* `MetalWerk_v1.jsfx` structured metal drum MIDI generator with layered Precision / Riff / Tribal identities and a form-aware `@gfx` editor.
* `OpenScaleEQ_v1.jsfx` original MIT-licensed scale-aware spectral EQ with in-key boosts, out-of-key cuts, auto major/minor key estimation, M/S width utilities, safety ceiling, and a custom spectral display.
* `OvumTone_v1.jsfx` five-oscillator stereo tone generator with continuous guitar-range frequency controls, wave morphing, per-oscillator low-pass filtering, trim, pan, and drone/MIDI-gated modes.
* `BloomWerk_v1.jsfx` deterministic harmonic-cloud send/instrument effect with audio chroma, MIDI field control, Hybrid Mode, Vines harmonic coupling, resonators, captured-input grains, Freeze/Memory performance controls, and a pitch-class debug view.
* `ScaleLane_v1.jsfx` lean 4-lane scale-aware melodic MIDI sequencer with per-lane patterns, chain playback, and a stopped-only `@gfx` step editor.
* `UndertowWerk_v1.jsfx` structured quiet/loud post-rock / math-rock MIDI drum generator with Anchor, Nerve, and Surge layers plus a form-aware `@gfx` editor.
* `WaterSplash_ModeGravity.jsfx` version 1 poc of an idea that a midi note is like a pebble hitting a water surface - causing splashes of midi notes like water droplets.
* `WaterSplash2` Version 2 of Water Splash - tidied the sliders. Grouped them and improved some of the note placements.

# Checks
* Run `./scripts/check_no_scientific_notation.sh` to verify there are no scientific-notation numeric literals in `Effects/`.
* Git pre-commit hook path is `.githooks` and runs this check automatically.

# UI Editing Rules
* Do not change control interaction behavior unless explicitly requested. Preserve existing step size, drag sensitivity, click semantics, and reachable values.
* For `@gfx` controls, avoid self-referential interaction math where changing a value also changes that control's drag resolution mid-gesture.
* For custom JSFX editors, follow `Docs/JSFX_GFX_NOTES.md`: `Effects/ParallelTap_v1.jsfx` is the reference loop for non-flickering graphics and non-clicking live parameter/audio state.
* Never share scratch/global variables between `@gfx` and `@sample`; wrap per-sample DSP in `@init` functions with `local(...)` scratch variables so graphics redraws cannot corrupt audio.
* If a UI behavior change is necessary, treat it as a deliberate UX change and call it out clearly rather than slipping it in with unrelated fixes.

# REAPER Voice Dataset Tooling
* Voice dataset ReaScripts for XTTS-style phrase import and render/export are documented in `Docs/VoiceDatasetREADME.md`.
* Example input CSV lives at `Docs/VoiceDatasetExample.csv`.

# BloomWerk MIDI Control
* BloomWerk routing and mode notes live in `Docs/BloomWerkREADME.md`.
* To control BloomWerk from WaterSplash/WaterWerk-style MIDI, put the MIDI generator on a separate REAPER track, send its MIDI to the BloomWerk track, and set BloomWerk to MIDI or Hybrid mode.
