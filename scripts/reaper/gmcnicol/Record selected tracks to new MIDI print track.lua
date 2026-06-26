-- @description Record selected tracks to new MIDI print track
-- @version 1.0
-- @author Codex
-- @about
--   Creates one new MIDI print track from the selected source track(s), starts
--   normal recording from the edit cursor or current play position, and removes
--   the temporary routing when recording stops.

local common = dofile((({ reaper.get_action_context() })[2]:match("^(.*[/\\])") or "") .. "LivePrint_SelectedTracks_Common.lua")

common.run({
  title = "Record selected tracks to new MIDI print track",
  track_name_prefix = "MIDI Print",
  signal_type = "midi",
  record_mode = 4,
  record_mode_flags = 0,
  send_mode = 0,
})
