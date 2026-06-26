# Scripts Layout

- `scripts/reaper/gmcnicol/`
  - ReaScripts (`.lua`) intended to be installed into:
    - `~/Library/Application Support/REAPER/Scripts/gmcnicol`
  - Preferred install path is via repo root deploy script:
    - `./deploy_to_reaper_gareth.sh`
  - Optional helper: `install_to_reaper.sh`
  - Live print scripts:
    - `Record selected tracks to new stereo print track.lua`
    - `Record selected tracks to new MIDI print track.lua`
    - Select one or more source tracks, run the stereo or MIDI script, then stop REAPER recording when the live print is done. If transport is already playing, recording starts from the current play position; otherwise it starts from the edit cursor.

- `scripts/`
  - General repo scripts that are **not** ReaScripts.
  - Examples:
    - `check_no_scientific_notation.sh`
    - `generate_vowelpad_capture_midi.py`
