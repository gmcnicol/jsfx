-- @description Voice Dataset - Render + Manifest Export
-- @version 1.0
-- @author Codex
-- @about
--   Exports deterministic WAV files plus XTTS-oriented manifests from a region/style/take workflow.

local common = dofile((({ reaper.get_action_context() })[2]:match("^(.*[/\\])") or "") .. "VoiceDataset_Common.lua")

local RENDER_ACTION_ID = 41824

local function build_region_plan(csv_rows)
  local regions = common.collect_regions()
  common.require(#regions > 0, "Project contains no regions")
  common.require(#regions == #csv_rows, string.format(
    "Project region count (%d) does not match CSV row count (%d)",
    #regions,
    #csv_rows
  ))

  local plan = {}
  for index, region in ipairs(regions) do
    local parsed = common.parse_region_name(region.name)
    common.require(parsed ~= nil, string.format("Region '%s' does not match 'phrase_id | transcript'", region.name))

    local row = csv_rows[index]
    common.require(parsed.phrase_id == row.phrase_id, string.format(
      "Region %d phrase_id '%s' does not match CSV row phrase_id '%s'",
      index,
      parsed.phrase_id,
      row.phrase_id
    ))
    common.require(parsed.transcript == row.text, string.format(
      "Region %d transcript does not match CSV for phrase_id '%s'",
      index,
      row.phrase_id
    ))

    plan[#plan + 1] = {
      region = region,
      row = row,
    }
  end

  return plan
end

local function item_overlaps_region(item, region_start, region_end)
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  return item_start < region_end and item_end > region_start
end

local function take_is_renderable(take)
  if not take then
    return false
  end
  if reaper.TakeIsMIDI(take) then
    return false
  end
  local source = reaper.GetMediaItemTake_Source(take)
  return source ~= nil
end

local function collect_track_examples(track_info, region)
  local examples = {}
  local track = track_info.track
  local item_count = reaper.CountTrackMediaItems(track)

  for item_index = 0, item_count - 1 do
    local item = reaper.GetTrackMediaItem(track, item_index)
    local item_muted = reaper.GetMediaItemInfo_Value(item, "B_MUTE_ACTUAL") > 0.5
    if not item_muted and item_overlaps_region(item, region.start_pos, region.end_pos) then
      local item_position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local lane_index = math.floor(reaper.GetMediaItemInfo_Value(item, "I_FIXEDLANE") or 0)
      local item_number = math.floor(reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER") or item_index)
      local take_count = reaper.CountTakes(item)

      for take_index = 0, take_count - 1 do
        local take = reaper.GetMediaItemTake(item, take_index)
        if take_is_renderable(take) then
          examples[#examples + 1] = {
            track = track,
            track_info = track_info,
            item = item,
            take = take,
            take_ordinal = take_index + 1,
            item_position = item_position,
            lane_index = lane_index,
            item_number = item_number,
          }
        end
      end
    end
  end

  table.sort(examples, common.example_sorter)
  return examples
end

local function collect_state_snapshot()
  local loop_start, loop_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  local snapshot = {
    loop_start = loop_start,
    loop_end = loop_end,
    cursor_pos = reaper.GetCursorPosition(),
    render_numeric = {},
    render_string = {},
    tracks = {},
    items = {},
  }

  local numeric_keys = {
    "RENDER_SETTINGS",
    "RENDER_BOUNDSFLAG",
    "RENDER_ADDTOPROJ",
    "RENDER_CHANNELS",
    "RENDER_SRATE",
    "RENDER_TAILFLAG",
    "RENDER_TAILMS",
    "RENDER_STARTPOS",
    "RENDER_ENDPOS",
  }

  local string_keys = {
    "RENDER_FILE",
    "RENDER_PATTERN",
    "RENDER_FORMAT",
    "RENDER_FORMAT2",
  }

  for _, key in ipairs(numeric_keys) do
    snapshot.render_numeric[key] = reaper.GetSetProjectInfo(0, key, 0, false)
  end

  for _, key in ipairs(string_keys) do
    local _, value = reaper.GetSetProjectInfo_String(0, key, "", false)
    snapshot.render_string[key] = value
  end

  for track_index = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, track_index)
    snapshot.tracks[#snapshot.tracks + 1] = {
      track = track,
      solo = reaper.GetMediaTrackInfo_Value(track, "I_SOLO"),
      mute = reaper.GetMediaTrackInfo_Value(track, "B_MUTE"),
    }

    local item_count = reaper.CountTrackMediaItems(track)
    for item_index = 0, item_count - 1 do
      local item = reaper.GetTrackMediaItem(track, item_index)
      snapshot.items[#snapshot.items + 1] = {
        item = item,
        mute = reaper.GetMediaItemInfo_Value(item, "B_MUTE"),
        all_takes_play = reaper.GetMediaItemInfo_Value(item, "B_ALLTAKESPLAY"),
        current_take = reaper.GetMediaItemInfo_Value(item, "I_CURTAKE"),
      }
    end
  end

  return snapshot
end

local function restore_state_snapshot(snapshot)
  reaper.GetSet_LoopTimeRange(true, false, snapshot.loop_start, snapshot.loop_end, false)
  reaper.SetEditCurPos(snapshot.cursor_pos, false, false)

  for key, value in pairs(snapshot.render_numeric) do
    reaper.GetSetProjectInfo(0, key, value, true)
  end

  for key, value in pairs(snapshot.render_string) do
    reaper.GetSetProjectInfo_String(0, key, value, true)
  end

  for _, track_state in ipairs(snapshot.tracks) do
    reaper.SetMediaTrackInfo_Value(track_state.track, "I_SOLO", track_state.solo)
    reaper.SetMediaTrackInfo_Value(track_state.track, "B_MUTE", track_state.mute)
  end

  for _, item_state in ipairs(snapshot.items) do
    reaper.SetMediaItemInfo_Value(item_state.item, "B_MUTE", item_state.mute)
    reaper.SetMediaItemInfo_Value(item_state.item, "B_ALLTAKESPLAY", item_state.all_takes_play)
    reaper.SetMediaItemInfo_Value(item_state.item, "I_CURTAKE", item_state.current_take)
  end
end

local function configure_render_target(output_dir, filename, region_start, region_end)
  reaper.GetSetProjectInfo_String(0, "RENDER_FILE", output_dir, true)
  reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", filename:gsub("%.wav$", ""), true)
  reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", "evaw", true)
  reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT2", "", true)
  reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", 0, true)
  reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 2, true)
  reaper.GetSetProjectInfo(0, "RENDER_ADDTOPROJ", 0, true)
  reaper.GetSet_LoopTimeRange(true, false, region_start, region_end, false)
end

local function set_render_focus(example)
  for track_index = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, track_index)
    reaper.SetMediaTrackInfo_Value(track, "I_SOLO", 0)
  end

  reaper.SetMediaTrackInfo_Value(example.track, "B_MUTE", 0)
  reaper.SetMediaTrackInfo_Value(example.track, "I_SOLO", 1)

  local item_count = reaper.CountTrackMediaItems(example.track)
  for item_index = 0, item_count - 1 do
    local item = reaper.GetTrackMediaItem(example.track, item_index)
    if item == example.item then
      reaper.SetMediaItemInfo_Value(item, "B_MUTE", 0)
      reaper.SetMediaItemInfo_Value(item, "B_ALLTAKESPLAY", 0)
      reaper.SetMediaItemInfo_Value(item, "I_CURTAKE", example.take_ordinal - 1)
    else
      reaper.SetMediaItemInfo_Value(item, "B_MUTE", 1)
    end
  end
end

local function render_example(output_dir, filename, region, example)
  local target_path = common.join_path(output_dir, filename)
  os.remove(target_path)
  configure_render_target(output_dir, filename, region.start_pos, region.end_pos)
  set_render_focus(example)
  reaper.Main_OnCommand(RENDER_ACTION_ID, 0)
  common.require(common.file_exists(target_path), "Expected render output was not created: " .. target_path)
end

local function build_manifests(region_plan, style_tracks)
  local metadata_lines = {}
  local full_manifest_lines = {
    "filename,phrase_id,transcript,track_name,take_index,important,expected_takes,region_start,region_end,section,notes"
  }
  local missing_lines = {
    "phrase_id,track_name,expected_takes,actual_takes,status"
  }
  local render_jobs = {}
  local filenames_seen = {}

  for _, plan_entry in ipairs(region_plan) do
    for _, track_info in ipairs(style_tracks) do
      local examples = collect_track_examples(track_info, plan_entry.region)
      local expected_takes = common.expected_takes_for_row(plan_entry.row)

      for index, example in ipairs(examples) do
        local filename = string.format("%s_%s_%d.wav", plan_entry.row.phrase_id, track_info.style_token, index)
        common.require(not filenames_seen[filename], "Duplicate planned output filename: " .. filename)
        filenames_seen[filename] = true

        local manifest_entry = {
          filename = filename,
          phrase_id = plan_entry.row.phrase_id,
          transcript = plan_entry.row.text,
          track_name = track_info.track_name,
          take_index = index,
          important = plan_entry.row.important,
          expected_takes = expected_takes,
          region_start = plan_entry.region.start_pos,
          region_end = plan_entry.region.end_pos,
          section = plan_entry.row.section,
          notes = plan_entry.row.notes,
        }

        metadata_lines[#metadata_lines + 1] = common.metadata_line(filename, plan_entry.row.text)
        full_manifest_lines[#full_manifest_lines + 1] = common.manifest_full_line(manifest_entry)
        render_jobs[#render_jobs + 1] = {
          filename = filename,
          region = plan_entry.region,
          example = example,
        }
      end

      local actual_takes = #examples
      if actual_takes < expected_takes then
        missing_lines[#missing_lines + 1] = common.missing_takes_line({
          phrase_id = plan_entry.row.phrase_id,
          track_name = track_info.track_name,
          expected_takes = expected_takes,
          actual_takes = actual_takes,
          status = actual_takes == 0 and "missing_all" or "missing_expected_takes",
        })
      end
    end
  end

  return {
    metadata_lines = metadata_lines,
    full_manifest_lines = full_manifest_lines,
    missing_lines = missing_lines,
    render_jobs = render_jobs,
  }
end

local function write_manifests(output_dir, manifests)
  common.write_text_file(common.join_path(output_dir, "metadata.csv"), table.concat(manifests.metadata_lines, "\n") .. "\n")
  common.write_text_file(common.join_path(output_dir, "manifest_full.csv"), table.concat(manifests.full_manifest_lines, "\n") .. "\n")
  common.write_text_file(common.join_path(output_dir, "missing_expected_takes.csv"), table.concat(manifests.missing_lines, "\n") .. "\n")
end

local function run()
  common.clear_console()
  common.log_header("Voice Dataset Render")

  local csv_path = common.choose_csv_file("Choose source CSV")
  if not csv_path then
    common.log("Render/export canceled before CSV selection.")
    return
  end

  local settings = common.prompt_render_settings(common.join_path(common.get_project_path(), "voice_dataset_export"))
  if not settings then
    common.log("Render/export canceled at settings prompt.")
    return
  end

  common.require(common.ensure_directory(settings.output_dir), "Could not create output directory: " .. settings.output_dir)

  local csv = common.read_csv_rows(csv_path)
  local style_tracks = common.collect_named_style_tracks(settings.unmuted_only)
  local region_plan = build_region_plan(csv.rows)
  local manifests = build_manifests(region_plan, style_tracks)

  common.log("CSV: " .. csv.path)
  common.log("Output directory: " .. settings.output_dir)
  common.log("Dry run: " .. common.bool_to_string(settings.dry_run))
  common.log("Style tracks: " .. tostring(#style_tracks))
  common.log("Planned renders: " .. tostring(#manifests.render_jobs))

  write_manifests(settings.output_dir, manifests)
  common.log("Wrote metadata.csv, manifest_full.csv, missing_expected_takes.csv")

  if settings.dry_run then
    common.message_box(
      string.format("Dry run complete.\nPlanned WAV files: %d\nOutput: %s", #manifests.render_jobs, settings.output_dir),
      "Voice Dataset Render"
    )
    return
  end

  local snapshot = collect_state_snapshot()
  reaper.PreventUIRefresh(1)

  local ok, err = xpcall(function()
    for _, job in ipairs(manifests.render_jobs) do
      common.log(string.format(
        "Rendering %s from %s on track %s",
        job.filename,
        job.region.name,
        job.example.track_info.track_name
      ))
      render_example(settings.output_dir, job.filename, job.region, job.example)
    end
  end, debug.traceback)

  restore_state_snapshot(snapshot)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()

  if not ok then
    common.fail(err, "Voice Dataset Render Failed")
  end

  common.message_box(
    string.format("Render complete.\nWAV files: %d\nOutput: %s", #manifests.render_jobs, settings.output_dir),
    "Voice Dataset Render"
  )
end

run()
