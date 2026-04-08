# Scripts Layout

- `scripts/reaper/gmcnicol/`
  - ReaScripts (`.lua`) intended to be installed into:
    - `~/Library/Application Support/REAPER/Scripts/gmcnicol`
  - Preferred install path is via repo root deploy script:
    - `./deploy_to_reaper_gareth.sh`
  - Optional helper: `install_to_reaper.sh`

- `scripts/`
  - General repo scripts that are **not** ReaScripts.
  - Examples:
    - `check_no_scientific_notation.sh`
    - `generate_vowelpad_capture_midi.py`
