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
    - Select one or more source tracks, run the stereo or MIDI script, then stop REAPER recording when the live print is done. The print track and temporary sends are created before recording starts. If transport is already playing, recording starts from the play position after setup settles; otherwise it starts from the edit cursor. The print track is inserted at the end of the project to avoid accidental folder-routing feedback.
  - Selection helpers:
    - `Select item under mouse - add or isolate.lua`
    - If the item under the mouse is not selected, adds it to the current item selection. If it is already selected, selects only that item, so running the action twice over the same item leaves a single selected item.

- `scripts/`
  - General repo scripts that are **not** ReaScripts.
  - Examples:
    - `check_no_scientific_notation.sh`
    - `generate_vowelpad_capture_midi.py`
