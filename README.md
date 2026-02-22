# JSFX
JSFX Scripts that I've written for Cockos Reaper.

# Included Effects
* `ccinterpolate` a JSFX Reimanging of Babyaudio's Transit2
* `WaterSplash_ModeGravity.jsfx` version 1 poc of an idea that a midi note is like a pebble hitting a water surface - causing splashes of midi notes like water droplets.
* `WaterSplash2` Version 2 of Water Splash - tidied the sliders. Grouped them and improved some of the note placements.

# Checks
* Run `./scripts/check_no_scientific_notation.sh` to verify there are no scientific-notation numeric literals in `Effects/`.
* Git pre-commit hook path is `.githooks` and runs this check automatically.
