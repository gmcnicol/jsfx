-- @description Record selected tracks to new stereo print track
-- @version 1.0
-- @author Codex
-- @about
--   Creates one new print track from the selected source track(s), starts normal
--   recording from the edit cursor or current play position, and removes the
--   temporary routing when recording stops.

local common = dofile((({ reaper.get_action_context() })[2]:match("^(.*[/\\])") or "") .. "LivePrint_SelectedTracks_Common.lua")

common.run({
  title = "Record selected tracks to new stereo print track",
  track_name_prefix = "Stereo Print",
  signal_type = "stereo",
  record_mode = 1,
  record_mode_flags = 0,
  send_mode = 0,
})
