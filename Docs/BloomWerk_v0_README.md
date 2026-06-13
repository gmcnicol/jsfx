# BloomWerk v0

BloomWerk v0 is a custom-GFX JSFX for harmonic pad loops and MIDI chord bloom.

## What It Does

- Audio input is captured into smooth looping pad voices. These are not one-shot grains.
- Pad loops use attack, long release, loop-edge crossfade, gain smoothing, slew limiting, soft limiting, and a final ceiling.
- MIDI input creates MIDI chord blooms for downstream VST instruments.
- Chord bloom is generational: with Major intervals, C emits C/E/G, then E and G can bloom into their own major intervals.
- Harmony is interval-set based. It does not clamp to a selected scale.

## Modes

- **Audio**: live audio creates wet pad-loop texture.
- **MIDI**: MIDI input outputs blooming MIDI chords.
- **Hybrid**: audio supplies pad-loop material while MIDI steers the harmonic field and emits chord bloom.

## Routing

Audio send:

```text
DI Guitar Track
  -> dry chain as normal
  -> send audio to BloomWerk v0
  -> BloomWerk wet output
  -> optional chorus/shimmer/reverb/distortion
```

MIDI steering:

```text
WaterSplash / WaterWerk MIDI Track
  -> send MIDI to BloomWerk v0
  -> BloomWerk outputs blooming MIDI chords to the next VSTi
```

The native JSFX sliders are hidden backing parameters. The user-facing surface is the custom `@gfx` panel.
