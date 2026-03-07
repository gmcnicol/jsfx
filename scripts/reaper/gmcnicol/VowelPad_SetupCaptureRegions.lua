-- @description VowelPad - Setup Capture Regions (120 BPM template)
-- @version 1.1
-- @author Codex
-- @about
--   Creates note regions that match Data/midi/VowelPad_capture_120bpm.mid timing.
--   Region names are: VowelPad|<prefix>|<midi>
--
--   Defaults:
--   - notes: 36..84 step 3
--   - pre-roll: 4 beats
--   - note length: 20 beats (10s at 120 BPM)
--   - gap: 4 beats (2s at 120 BPM)

local NOTE_START = 36
local NOTE_END = 84
local NOTE_STEP = 3
local PRE_ROLL_BEATS = 4
local NOTE_LENGTH_BEATS = 20
local GAP_BEATS = 4

local DEFAULT_PREFIX = "A_clean"
local DEFAULT_TAIL_SECONDS = "1.2"
local DEFAULT_BPM = "120"
local DEFAULT_CLEAR_EXISTING = "1"

local function starts_with(text, prefix)
  return text:sub(1, #prefix) == prefix
end

local function beats_to_seconds(beats, bpm)
  return beats * (60.0 / bpm)
end

local function clear_vowelpad_regions()
  local project = 0
  local marker_count, region_count = reaper.CountProjectMarkers(project)
  local total = marker_count + region_count

  for marker_index = total - 1, 0, -1 do
    local ok, is_region, _, _, name = reaper.EnumProjectMarkers(marker_index)
    if ok and is_region and name and starts_with(name, "VowelPad|") then
      reaper.DeleteProjectMarkerByIndex(project, marker_index)
    end
  end
end

local function get_anchor_seconds()
  local play_state = reaper.GetPlayState()
  if (play_state & 1) == 1 then
    return reaper.GetPlayPosition()
  end
  return reaper.GetCursorPosition()
end

local function create_regions(prefix, bpm, tail_seconds, anchor_seconds)
  local region_count = 0
  local beat_cursor = PRE_ROLL_BEATS

  local first_start = nil
  local last_end = nil

  for midi_note = NOTE_START, NOTE_END, NOTE_STEP do
    local note_on_sec = anchor_seconds + beats_to_seconds(beat_cursor, bpm)
    local note_off_sec = anchor_seconds + beats_to_seconds(beat_cursor + NOTE_LENGTH_BEATS, bpm)
    local next_note_on_sec = anchor_seconds + beats_to_seconds(beat_cursor + NOTE_LENGTH_BEATS + GAP_BEATS, bpm)

    local region_end = note_off_sec + tail_seconds
    local hard_cap = next_note_on_sec - 0.01
    if region_end > hard_cap then
      region_end = hard_cap
    end
    if region_end <= note_on_sec + 0.05 then
      region_end = note_off_sec
    end

    local name = string.format("VowelPad|%s|%03d", prefix, midi_note)
    reaper.AddProjectMarker2(0, true, note_on_sec, region_end, name, -1, 0)

    first_start = first_start or note_on_sec
    last_end = region_end

    region_count = region_count + 1
    beat_cursor = beat_cursor + NOTE_LENGTH_BEATS + GAP_BEATS
  end

  if first_start and last_end and last_end > first_start then
    reaper.GetSet_LoopTimeRange(true, false, first_start, last_end, false)
  end

  return region_count, first_start, last_end
end

local function parse_inputs()
  local ok, values = reaper.GetUserInputs(
    "VowelPad Capture Regions",
    4,
    "Prefix,Tail Seconds,Set BPM (0=leave),Clear old VowelPad regions (0/1)",
    table.concat({
      DEFAULT_PREFIX,
      DEFAULT_TAIL_SECONDS,
      DEFAULT_BPM,
      DEFAULT_CLEAR_EXISTING
    }, ",")
  )

  if not ok then
    return nil
  end

  local prefix, tail_text, bpm_text, clear_text = values:match("([^,]*),([^,]*),([^,]*),([^,]*)")

  prefix = (prefix and prefix ~= "") and prefix or DEFAULT_PREFIX

  local tail_seconds = tonumber(tail_text) or tonumber(DEFAULT_TAIL_SECONDS)
  if tail_seconds < 0 then tail_seconds = 0 end
  if tail_seconds > 10 then tail_seconds = 10 end

  local bpm = tonumber(bpm_text) or 0
  if bpm < 0 then bpm = 0 end

  local clear_existing = tonumber(clear_text) or 0
  clear_existing = clear_existing >= 0.5 and 1 or 0

  return prefix, tail_seconds, bpm, clear_existing
end

local prefix, tail_seconds, bpm, clear_existing = parse_inputs()
if not prefix then
  return
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

if clear_existing == 1 then
  clear_vowelpad_regions()
end

if bpm > 0 then
  reaper.SetCurrentBPM(0, bpm, true)
else
  bpm = reaper.Master_GetTempo()
end

local anchor_seconds = get_anchor_seconds()
local count, first_start, last_end = create_regions(prefix, bpm, tail_seconds, anchor_seconds)

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("VowelPad: Setup capture regions", -1)

local message = string.format(
  "Created %d regions\nPrefix: %s\nTempo: %.2f BPM\nAnchor: %.2fs\nTail: %.2fs",
  count,
  prefix,
  bpm,
  anchor_seconds,
  tail_seconds
)

if first_start and last_end then
  message = message .. string.format("\nRange: %.2fs - %.2fs", first_start, last_end)
end

reaper.ShowMessageBox(message, "VowelPad Capture Regions", 0)
