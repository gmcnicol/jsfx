# JSFX
JSFX Scripts that I've written for Cockos Reaper.

# Included Effects
* `ccinterpolate` a JSFX Reimanging of Babyaudio's Transit2
* `CrescendoWerk_v1.jsfx` structured post-rock / post-metal MIDI drum generator with Patient Pulse, Procession / Tension, and Weight / Tom Motion layers plus a form-aware `@gfx` editor.
* `DanseWerk_v1.jsfx` structured EBM / industrial MIDI drum generator with Command / Contamination / Punishment layers and a form-aware `@gfx` editor.
* `MetalWerk_v1.jsfx` structured metal drum MIDI generator with layered Precision / Riff / Tribal identities and a form-aware `@gfx` editor.
* `UndertowWerk_v1.jsfx` structured quiet/loud post-rock / math-rock MIDI drum generator with Anchor, Nerve, and Surge layers plus a form-aware `@gfx` editor.
* `WaterSplash_ModeGravity.jsfx` version 1 poc of an idea that a midi note is like a pebble hitting a water surface - causing splashes of midi notes like water droplets.
* `WaterSplash2` Version 2 of Water Splash - tidied the sliders. Grouped them and improved some of the note placements.

# Checks
* Run `./scripts/check_no_scientific_notation.sh` to verify there are no scientific-notation numeric literals in `Effects/`.
* Git pre-commit hook path is `.githooks` and runs this check automatically.
