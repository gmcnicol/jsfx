local M = {}

local PLAY_STATE_RECORDING = 4
local SEND_CATEGORY = 0
local SEND_MIDI_DISABLED = 31

local function show_message(message, title)
  reaper.ShowMessageBox(message, title or "Live Print Selected Tracks", 0)
end

local function fail(message)
  show_message(message, "Live Print Selected Tracks")
  error(message, 0)
end

local function is_recording()
  return (reaper.GetPlayState() & PLAY_STATE_RECORDING) == PLAY_STATE_RECORDING
end

local function track_is_valid(track)
  if not track then
    return false
  end
  if reaper.ValidatePtr2 then
    return reaper.ValidatePtr2(0, track, "MediaTrack*")
  end
  return true
end

local function get_track_index(track)
  return math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") or 0) - 1
end

local function get_track_name(track)
  local ok, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  if ok and name and name ~= "" then
    return name
  end
  return string.format("Track %d", get_track_index(track) + 1)
end

local function collect_selected_tracks()
  local selected = {}
  local count = reaper.CountSelectedTracks(0)

  for index = 0, count - 1 do
    local track = reaper.GetSelectedTrack(0, index)
    selected[#selected + 1] = {
      track = track,
      index = get_track_index(track),
      name = get_track_name(track),
    }
  end

  table.sort(selected, function(left, right)
    return left.index < right.index
  end)

  return selected
end

local function snapshot_track_state()
  local snapshot = {}

  for index = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, index)
    snapshot[#snapshot + 1] = {
      track = track,
      selected = reaper.GetMediaTrackInfo_Value(track, "I_SELECTED"),
      recarm = reaper.GetMediaTrackInfo_Value(track, "I_RECARM"),
    }
  end

  return snapshot
end

local function restore_track_state(snapshot)
  for index = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, index)
    reaper.SetTrackSelected(track, false)
    reaper.SetMediaTrackInfo_Value(track, "I_RECARM", 0)
  end

  for _, state in ipairs(snapshot) do
    if track_is_valid(state.track) then
      reaper.SetTrackSelected(state.track, state.selected >= 0.5)
      reaper.SetMediaTrackInfo_Value(state.track, "I_RECARM", state.recarm)
    end
  end
end

local function restore_track_selection(snapshot)
  for index = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, index)
    reaper.SetTrackSelected(track, false)
  end

  for _, state in ipairs(snapshot) do
    if track_is_valid(state.track) then
      reaper.SetTrackSelected(state.track, state.selected >= 0.5)
    end
  end
end

local function disarm_all_tracks()
  for index = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, index)
    reaper.SetMediaTrackInfo_Value(track, "I_RECARM", 0)
  end
end

local function build_capture_track_name(config, selected_tracks)
  if #selected_tracks == 1 then
    return string.format("%s - %s", config.track_name_prefix, selected_tracks[1].name)
  end
  return string.format("%s - %d tracks", config.track_name_prefix, #selected_tracks)
end

local function create_capture_track(config, selected_tracks)
  local insert_index = selected_tracks[#selected_tracks].index + 1
  local track_count = reaper.CountTracks(0)
  if insert_index > track_count then
    insert_index = track_count
  end

  reaper.InsertTrackAtIndex(insert_index, true)

  local capture_track = reaper.GetTrack(0, insert_index)
  if not capture_track then
    fail("Could not create capture track.")
  end

  reaper.GetSetMediaTrackInfo_String(
    capture_track,
    "P_NAME",
    build_capture_track_name(config, selected_tracks),
    true
  )
  reaper.SetMediaTrackInfo_Value(capture_track, "I_NCHAN", 2)
  reaper.SetMediaTrackInfo_Value(capture_track, "I_RECINPUT", -1)
  reaper.SetMediaTrackInfo_Value(capture_track, "I_RECMODE", config.record_mode)
  reaper.SetMediaTrackInfo_Value(capture_track, "I_RECMODE_FLAGS", config.record_mode_flags or 0)
  reaper.SetMediaTrackInfo_Value(capture_track, "I_RECMON", 0)
  reaper.SetMediaTrackInfo_Value(capture_track, "I_RECMONITEMS", 0)
  reaper.SetMediaTrackInfo_Value(capture_track, "B_AUTO_RECARM", 0)
  reaper.SetMediaTrackInfo_Value(capture_track, "I_RECARM", 1)

  return capture_track
end

local function configure_send(source_track, send_index, config)
  reaper.SetTrackSendInfo_Value(source_track, SEND_CATEGORY, send_index, "B_MUTE", 0)
  reaper.SetTrackSendInfo_Value(source_track, SEND_CATEGORY, send_index, "D_VOL", 1.0)
  reaper.SetTrackSendInfo_Value(source_track, SEND_CATEGORY, send_index, "D_PAN", 0.0)
  reaper.SetTrackSendInfo_Value(source_track, SEND_CATEGORY, send_index, "I_SENDMODE", config.send_mode or 0)
  reaper.SetTrackSendInfo_Value(source_track, SEND_CATEGORY, send_index, "I_DSTCHAN", 0)

  if config.signal_type == "stereo" then
    reaper.SetTrackSendInfo_Value(source_track, SEND_CATEGORY, send_index, "I_SRCCHAN", 0)
    reaper.SetTrackSendInfo_Value(source_track, SEND_CATEGORY, send_index, "I_MIDIFLAGS", SEND_MIDI_DISABLED)
  elseif config.signal_type == "midi" then
    reaper.SetTrackSendInfo_Value(source_track, SEND_CATEGORY, send_index, "I_SRCCHAN", -1)
    reaper.SetTrackSendInfo_Value(source_track, SEND_CATEGORY, send_index, "I_MIDIFLAGS", 0)
  else
    fail("Unknown live print signal type: " .. tostring(config.signal_type))
  end
end

local function create_temporary_sends(selected_tracks, capture_track, config)
  local sends = {}

  for _, source in ipairs(selected_tracks) do
    local send_index = reaper.CreateTrackSend(source.track, capture_track)
    if send_index < 0 then
      fail("Could not create send from " .. source.name .. ".")
    end

    configure_send(source.track, send_index, config)
    sends[#sends + 1] = {
      source_track = source.track,
      send_index = send_index,
    }
  end

  return sends
end

local function find_send_to_track(source_track, destination_track)
  local send_count = reaper.GetTrackNumSends(source_track, SEND_CATEGORY)
  for send_index = 0, send_count - 1 do
    local send_destination = reaper.GetTrackSendInfo_Value(source_track, SEND_CATEGORY, send_index, "P_DESTTRACK")
    if send_destination == destination_track then
      return send_index
    end
  end
  return nil
end

local function remove_temporary_sends(sends, capture_track)
  for index = #sends, 1, -1 do
    local send = sends[index]
    if track_is_valid(send.source_track) then
      local send_index = nil
      local destination = reaper.GetTrackSendInfo_Value(send.source_track, SEND_CATEGORY, send.send_index, "P_DESTTRACK")

      if destination == capture_track then
        send_index = send.send_index
      else
        send_index = find_send_to_track(send.source_track, capture_track)
      end

      if send_index then
        reaper.RemoveTrackSend(send.source_track, SEND_CATEGORY, send_index)
      end
    end
  end
end

function M.run(config)
  local title = config.title or "Live Print Selected Tracks"

  if is_recording() then
    show_message("Stop recording before running this print script.", title)
    return
  end

  local selected_tracks = collect_selected_tracks()
  if #selected_tracks == 0 then
    show_message("Select one or more source tracks before running this print script.", title)
    return
  end

  local track_snapshot = snapshot_track_state()
  local capture_track = nil
  local sends = {}
  local cleaned = false

  local function cleanup()
    if cleaned then
      return
    end
    cleaned = true

    reaper.PreventUIRefresh(1)
    remove_temporary_sends(sends, capture_track)
    if track_is_valid(capture_track) then
      reaper.SetMediaTrackInfo_Value(capture_track, "I_RECARM", 0)
      reaper.SetMediaTrackInfo_Value(capture_track, "B_MAINSEND", 1)
    end
    restore_track_state(track_snapshot)
    reaper.PreventUIRefresh(-1)
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()
  end

  reaper.atexit(cleanup)

  local ok, err = xpcall(function()
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    disarm_all_tracks()
    capture_track = create_capture_track(config, selected_tracks)
    reaper.SetMediaTrackInfo_Value(capture_track, "B_MAINSEND", 0)
    sends = create_temporary_sends(selected_tracks, capture_track, config)
    restore_track_selection(track_snapshot)
    reaper.SetMediaTrackInfo_Value(capture_track, "I_RECARM", 1)

    reaper.PreventUIRefresh(-1)
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock(title, -1)
  end, debug.traceback)

  if not ok then
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock(title .. " (failed)", -1)
    cleanup()
    fail(err)
  end

  reaper.CSurf_OnRecord()

  local started_recording = false
  local start_wait_count = 0

  local function watch_recording()
    if is_recording() then
      started_recording = true
      reaper.defer(watch_recording)
      return
    end

    if not started_recording and start_wait_count < 10 then
      start_wait_count = start_wait_count + 1
      reaper.defer(watch_recording)
      return
    end

    if not started_recording then
      show_message("Recording did not start. Temporary routing was removed.", title)
    end

    cleanup()
  end

  reaper.defer(watch_recording)
end

return M
