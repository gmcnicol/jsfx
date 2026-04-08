# VowelPad NOTES

## Implementation Summary
- Mono/legato MIDI synth with held-note stack and optional drone fallback.
- Exciter source blends triangle and saw, then applies a mild polynomial softening step.
- Breath noise is lowpassed and injected pre-formant.
- Three-formant parallel RBJ bandpass bank morphs continuously across A/E/I/O/U frequency sets.
- Slow per-voice drift, global vibrato, unison detune, and stereo spread add movement.
- Chorus is a stereo dual-delay with bounded feedback and hard delay bounds.
- Mojo stage uses asymmetric soft clipping with bias, tone smoothing, and oversample averaging.

## Safety / Stability
- ADSR and key timbre sliders are smoothed with one-pole slews.
- Release path is explicit and click-safe for normal pad settings.
- Chorus feedback is clamped and fixed low (`0.10`) to avoid runaway.
- DC blocker follows mojo to reduce low-frequency offset from asymmetry.
- Final output passes through a soft clamp.

## Oversampling Strategy
- Selector maps to factors `1x`, `2x`, `4x`, `8x`.
- Nonlinearity runs `os_factor` times per sample on held input and averages output.
- Internal tone smoothing in the mojo path helps reduce imaging harshness.

## CPU Notes
- The design is optimized for a single lush pad instance on a modern machine.
- Expensive operations are constrained: 3 formants, max 7 unison lanes, compact delay buffers.
- Formant coefficient updates are decimated (every 16 samples) while slider values are smoothed continuously.
