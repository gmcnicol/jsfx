-- @description Voice Dataset - Phrase Import / Teleprompt Setup
-- @version 1.0
-- @author Codex
-- @about
--   Imports a phrase CSV into REAPER regions and an optional Teleprompt Guide track.

local common = dofile((({ reaper.get_action_context() })[2]:match("^(.*[/\\])") or "") .. "VoiceDataset_Common.lua")

local SECTION_MARKER_PREFIX = "SECTION | "

local function delete_matching_regions(phrase_rows)
  local phrase_prefixes = {}
  for _, row in ipairs(phrase_rows) do
    phrase_prefixes[row.phrase_id .. " | "] = true
  end

  local marker_count, region_count = reaper.CountProjectMarkers(0)
  local total = marker_count + region_count

  for marker_index = total - 1, 0, -1 do
    local ok, is_region, _, _, name = reaper.EnumProjectMarkers(marker_index)
    if ok and is_region then
      local should_delete = false
      for prefix in pairs(phrase_prefixes) do
        if common.starts_with(name or "", prefix) then
          should_delete = true
          break
        end
      end
      if should_delete then
        reaper.DeleteProjectMarkerByIndex(0, marker_index)
      end
    end
  end
end

local function delete_section_markers()
  local marker_count, region_count = reaper.CountProjectMarkers(0)
  local total = marker_count + region_count

  for marker_index = total - 1, 0, -1 do
    local ok, is_region, _, _, name = reaper.EnumProjectMarkers(marker_index)
    if ok and not is_region and common.starts_with(name or "", SECTION_MARKER_PREFIX) then
      reaper.DeleteProjectMarkerByIndex(0, marker_index)
    end
  end
end

local function upsert_guide_item(track, row, start_pos, end_pos)
  local item = reaper.AddMediaItemToTrack(track)
  reaper.SetMediaItemPosition(item, start_pos, false)
  reaper.SetMediaItemLength(item, end_pos - start_pos, false)

  local take = reaper.AddTakeToMediaItem(item)
  local visible_name = row.text
  if row.important then
    visible_name = "[IMPORTANT] " .. visible_name
  end
  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", visible_name, true)

  return item
end

local function clear_track_items(track)
  for item_index = reaper.CountTrackMediaItems(track) - 1, 0, -1 do
    local item = reaper.GetTrackMediaItem(track, item_index)
    reaper.DeleteTrackMediaItem(track, item)
  end
end

local function maybe_add_section_marker(previous_section, row, start_pos, enabled)
  if not enabled then
    return previous_section
  end

  local section = row.section
  if section == "" or section == previous_section then
    return previous_section
  end

  local marker_name = SECTION_MARKER_PREFIX .. section
  reaper.AddProjectMarker2(0, false, start_pos, 0, marker_name, -1, 0)
  common.log(string.format("Created marker: %s @ %s", marker_name, common.format_seconds(start_pos)))
  return section
end

local function run()
  common.clear_console()
  common.log_header("Voice Dataset Import")

  local csv_path = common.choose_csv_file("Choose phrase CSV")
  if not csv_path then
    common.log("Import canceled before CSV selection.")
    return
  end

  local settings = common.prompt_import_settings()
  if not settings then
    common.log("Import canceled at settings prompt.")
    return
  end

  local csv = common.read_csv_rows(csv_path)
  common.log("CSV: " .. csv.path)
  common.log("Rows: " .. tostring(#csv.rows))

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local ok, err = xpcall(function()
    if settings.clear_existing then
      delete_matching_regions(csv.rows)
      delete_section_markers()
      common.log("Cleared existing dataset regions/section markers matching this CSV.")
    end

    local guide_track = nil
    if settings.create_guide_track then
      guide_track = select(1, common.find_or_create_track("Teleprompt Guide"))
      if settings.clear_existing then
        clear_track_items(guide_track)
        common.log("Cleared existing Teleprompt Guide items.")
      end
      common.log("Guide track ready: Teleprompt Guide")
    end

    local cursor = 0.0
    local previous_section = ""

    for _, row in ipairs(csv.rows) do
      local region_start = cursor
      local region_end = cursor + row.max_seconds
      local region_name = common.format_region_name(row.phrase_id, row.text)

      previous_section = maybe_add_section_marker(previous_section, row, region_start, settings.create_section_markers)

      reaper.AddProjectMarker2(0, true, region_start, region_end, region_name, -1, 0)
      common.log(string.format(
        "Created region: %s [%s - %s]",
        region_name,
        common.format_seconds(region_start),
        common.format_seconds(region_end)
      ))

      if guide_track then
        upsert_guide_item(guide_track, row, region_start, region_end)
        common.log("Created guide item for " .. row.phrase_id)
      end

      cursor = region_end + settings.gap_seconds
    end
  end, debug.traceback)

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()

  if ok then
    reaper.Undo_EndBlock("Voice Dataset: Phrase Import / Teleprompt Setup", -1)
    local message = string.format(
      "Imported %d phrases from %s",
      #csv.rows,
      csv_path
    )
    common.message_box(message, "Voice Dataset Import")
  else
    reaper.Undo_EndBlock("Voice Dataset: Phrase Import / Teleprompt Setup (failed)", -1)
    common.fail(err, "Voice Dataset Import Failed")
  end
end

run()
