# VowelPad README

## What It Is
`VowelPadMojo.jsfx` is a mono/legato pad synth in JSFX with:
- vowel/formant synthesis (A/E/I/O/U morph)
- unison stereo spread with drift and vibrato
- built-in chorus
- mojo saturation with 1x/2x/4x/8x oversampling
- click-safe ADSR and final safety clamping

## Install / Use
1. Place `VowelPadMojo.jsfx` in your REAPER Effects path (or deploy this repo to your JSFX folder).
2. Insert it on a track.
3. Feed MIDI notes.
4. Start from the default patch and adjust `Vowel Pos`, `Formant Q`, and `Drive`.

## Signal Flow
`Source -> Formant Bank -> Brightness Tilt -> Chorus -> Mojo Saturation(OS) -> DC Block -> Output Soft Clamp`

## Good Starting Settings
- `Unison Count`: `5`
- `Detune`: `10`
- `Stereo Width`: `0.8`
- `Vowel Pos`: `0.8`
- `Formant Q`: `11`
- `Breath`: `12%`
- `Attack/Decay/Sustain/Release`: `350 / 800 / 0.7 / 1200`
- `Chorus Mix`: `0.35`
- `Drive/Bias/OS`: `8 dB / 0.15 / 4x`
- `Output`: `-6 dB`

## Notes
- This version is intentionally mono/legato for CPU stability.
- Oversampling mostly affects the mojo stage when drive is high.
- `Attack >= 10 ms` and `Release >= 200 ms` are recommended for pop-safe playing.
