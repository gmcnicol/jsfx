# REAPER Voice Dataset Tooling

This repo now includes two Lua ReaScripts for preparing XTTS-style voice datasets from a structured REAPER project:

1. `VoiceDataset_PhraseImport.lua`
2. `VoiceDataset_RenderExport.lua`

Both scripts live in `scripts/reaper/gmcnicol/` and install through the existing REAPER script sync flow.

## Files

- ReaScripts: `scripts/reaper/gmcnicol/`
- Example CSV: `Docs/VoiceDatasetExample.csv`
- Install to local REAPER: `./deploy_to_reaper_gareth.sh`

## Project Conventions

- One region = one phrase / transcript unit.
- One named track = one speaking style.
- Default style examples are `normal`, `tense`, and `slow`, but any non-empty track name is allowed.
- The guide track name is reserved as `Teleprompt Guide` and is ignored by the render/export script.
- One overlapping item on a style track inside a region = one dataset example.
- Multiple takes inside a single overlapping item are also treated as separate examples.

Output filenames are always:

- `{phrase_id}_{style}_{take_index}.wav`

Example:

- `0001_normal_1.wav`
- `0001_tense_2.wav`
- `0002_slow_1.wav`

Transcript text never appears in filenames.

## CSV Schema

Required columns:

- `phrase_id`
- `text`
- `max_seconds`

Optional columns:

- `important`
- `takes_per_style`
- `section`
- `style_hint`
- `notes`

`important` and `takes_per_style` drive expected take counts:

- `important=true` and blank `takes_per_style` => expected takes per enabled style = `2`
- `important=false` and blank `takes_per_style` => expected takes per enabled style = `1`
- present `takes_per_style` overrides both defaults

The scripts reject transcript text containing `|` because `metadata.csv` uses `filename|transcript`.

## Phrase Import Workflow

1. Run `VoiceDataset_PhraseImport.lua`.
2. Choose the phrase CSV.
3. Set:
   - whether to clear existing dataset regions
   - the gap between regions in seconds
   - whether to create the guide track
   - whether to create section markers
4. The script creates regions in CSV order with names like:
   - `0001 | I’m going to tell this plainly.`
5. If enabled, it creates:
   - section markers named `SECTION | <section>`
   - a `Teleprompt Guide` track with one empty guide item per phrase

Important rows are tagged as `[IMPORTANT]` in the guide item take name.

## Render / Export Workflow

1. Record onto named style tracks.
2. Use separate overlapping items, fixed lanes, or multiple takes to capture alternates.
3. Run `VoiceDataset_RenderExport.lua`.
4. Choose the same source CSV again.
5. Enter:
   - output directory
   - dry-run mode (`1`) or real render mode (`0`)
   - whether to include only unmuted named tracks

The render script then:

- validates that project regions match the CSV in both order and content
- enumerates named style tracks in track-index order
- detects overlapping examples per region/style
- assigns deterministic take indexes
- writes:
  - `metadata.csv`
  - `manifest_full.csv`
  - `missing_expected_takes.csv`
- optionally renders one WAV per valid example

## Manifests

### `metadata.csv`

Format:

```text
filename|transcript
```

### `manifest_full.csv`

Columns:

```text
filename,phrase_id,transcript,track_name,take_index,important,expected_takes,region_start,region_end,section,notes
```

### `missing_expected_takes.csv`

Columns:

```text
phrase_id,track_name,expected_takes,actual_takes,status
```

Status values currently used:

- `missing_all`
- `missing_expected_takes`

## Validation Rules

The scripts fail loudly instead of silently skipping data. Current hard failures include:

- missing required CSV columns
- duplicate or blank `phrase_id`
- blank `text`
- non-positive `max_seconds`
- transcript text containing `|`
- project region count not matching CSV row count
- region names not matching `{phrase_id} | {text}`
- blank tracks with media items
- duplicate planned output filenames

## Notes

- Render/export forces WAV output but otherwise relies on REAPER’s current render engine.
- Real renders temporarily solo the target style track, mute non-target items on that track, render the region time selection, then restore project state.
- Dry-run mode writes manifests without creating WAV files.
