local M = {}

local function get_script_path()
  local _, path = reaper.get_action_context()
  return path or ""
end

function M.get_script_dir()
  local path = get_script_path()
  return path:match("^(.*[/\\])") or ""
end

function M.load_sibling(module_name)
  local path = M.get_script_dir() .. module_name
  return dofile(path)
end

function M.trim(value)
  if value == nil then
    return ""
  end
  return tostring(value):match("^%s*(.-)%s*$") or ""
end

function M.lower_trim(value)
  return string.lower(M.trim(value))
end

function M.starts_with(text, prefix)
  return text:sub(1, #prefix) == prefix
end

function M.file_exists(path)
  local handle = io.open(path, "rb")
  if handle then
    handle:close()
    return true
  end
  return false
end

function M.ensure_directory(path)
  local ok = reaper.RecursiveCreateDirectory(path, 0)
  return ok == 1 or ok == true
end

function M.join_path(dir_path, leaf)
  if dir_path:sub(-1) == "/" or dir_path:sub(-1) == "\\" then
    return dir_path .. leaf
  end
  return dir_path .. "/" .. leaf
end

function M.clear_console()
  reaper.ClearConsole()
end

function M.log(text)
  reaper.ShowConsoleMsg(tostring(text) .. "\n")
end

function M.log_header(title)
  M.log("")
  M.log("== " .. title .. " ==")
end

function M.message_box(text, title)
  reaper.ShowMessageBox(text, title or "Voice Dataset Tooling", 0)
end

function M.fail(message, title)
  M.log("ERROR: " .. message)
  M.message_box(message, title or "Voice Dataset Tooling Error")
  error(message, 0)
end

function M.require(condition, message, title)
  if not condition then
    M.fail(message, title)
  end
end

function M.bool_from_csv(value)
  local lowered = M.lower_trim(value)
  if lowered == "" then
    return false
  end
  return lowered == "1" or lowered == "true" or lowered == "yes" or lowered == "y"
end

function M.bool_to_string(value)
  if value then
    return "true"
  end
  return "false"
end

function M.parse_positive_number(raw, field_name, line_number)
  local value = tonumber(M.trim(raw))
  if not value or value <= 0 then
    M.fail(string.format("Line %d: %s must be a positive number", line_number, field_name))
  end
  return value
end

function M.parse_optional_positive_integer(raw, field_name, line_number)
  local trimmed = M.trim(raw)
  if trimmed == "" then
    return nil
  end
  local value = tonumber(trimmed)
  if not value or value < 1 or value ~= math.floor(value) then
    M.fail(string.format("Line %d: %s must be a positive integer when present", line_number, field_name))
  end
  return value
end

function M.normalize_phrase_id(raw, line_number)
  local phrase_id = M.trim(raw)
  if phrase_id == "" then
    M.fail(string.format("Line %d: phrase_id cannot be blank", line_number))
  end
  if phrase_id:find("[%s|,]") then
    M.fail(string.format("Line %d: phrase_id '%s' contains whitespace or delimiter characters", line_number, phrase_id))
  end
  return phrase_id
end

function M.validate_transcript(raw, line_number)
  local text = M.trim(raw)
  if text == "" then
    M.fail(string.format("Line %d: text cannot be blank", line_number))
  end
  if text:find("|", 1, true) then
    M.fail(string.format("Line %d: text contains '|' which would break metadata.csv", line_number))
  end
  if text:find("[\r\n]") then
    M.fail(string.format("Line %d: text contains a newline; multiline transcript fields are not supported", line_number))
  end
  return text
end

function M.parse_csv_line(line)
  local fields = {}
  local i = 1
  local length = #line

  while i <= length do
    local char = line:sub(i, i)
    if char == '"' then
      local j = i + 1
      local buffer = {}
      while j <= length do
        local c = line:sub(j, j)
        if c == '"' then
          if line:sub(j + 1, j + 1) == '"' then
            buffer[#buffer + 1] = '"'
            j = j + 2
          else
            j = j + 1
            break
          end
        else
          buffer[#buffer + 1] = c
          j = j + 1
        end
      end
      if j - 1 > length and line:sub(length, length) ~= '"' then
        return nil, "unterminated quoted field"
      end
      fields[#fields + 1] = table.concat(buffer)
      if j <= length then
        if line:sub(j, j) ~= "," then
          return nil, "expected comma after closing quote"
        end
        i = j + 1
      else
        i = j + 1
      end
    else
      local j = i
      while j <= length and line:sub(j, j) ~= "," do
        j = j + 1
      end
      fields[#fields + 1] = line:sub(i, j - 1)
      i = j + 1
    end
  end

  if line:sub(-1) == "," then
    fields[#fields + 1] = ""
  end

  return fields
end

function M.csv_escape(value)
  local text = tostring(value or "")
  if text:find('[,"\r\n]') then
    text = '"' .. text:gsub('"', '""') .. '"'
  end
  return text
end

function M.write_text_file(path, text)
  local handle, err = io.open(path, "wb")
  if not handle then
    M.fail(string.format("Could not write %s: %s", path, err or "unknown error"))
  end
  handle:write(text)
  handle:close()
end

function M.read_csv_rows(path)
  local handle, err = io.open(path, "rb")
  if not handle then
    M.fail(string.format("Could not open CSV file %s: %s", path, err or "unknown error"))
  end

  local header_line = handle:read("*l")
  if not header_line then
    handle:close()
    M.fail("CSV file is empty")
  end

  header_line = header_line:gsub("^\239\187\191", "")

  local header_fields, header_err = M.parse_csv_line(header_line)
  if not header_fields then
    handle:close()
    M.fail("Could not parse CSV header: " .. header_err)
  end

  local header_lookup = {}
  for index, field in ipairs(header_fields) do
    local key = M.lower_trim(field)
    if key == "" then
      handle:close()
      M.fail(string.format("CSV header column %d is blank", index))
    end
    if header_lookup[key] then
      handle:close()
      M.fail(string.format("CSV header contains duplicate column '%s'", key))
    end
    header_lookup[key] = index
  end

  local required_columns = { "phrase_id", "text", "max_seconds" }
  for _, key in ipairs(required_columns) do
    if not header_lookup[key] then
      handle:close()
      M.fail("CSV is missing required column: " .. key)
    end
  end

  local rows = {}
  local seen_phrase_ids = {}
  local line_number = 1

  while true do
    local line = handle:read("*l")
    if line == nil then
      break
    end
    line_number = line_number + 1

    if M.trim(line) ~= "" then
      local fields, parse_err = M.parse_csv_line(line)
      if not fields then
        handle:close()
        M.fail(string.format("Line %d: %s", line_number, parse_err))
      end

      local function get_column(name)
        local index = header_lookup[name]
        if not index then
          return ""
        end
        return fields[index] or ""
      end

      local row = {
        line_number = line_number,
        phrase_id = M.normalize_phrase_id(get_column("phrase_id"), line_number),
        text = M.validate_transcript(get_column("text"), line_number),
        max_seconds = M.parse_positive_number(get_column("max_seconds"), "max_seconds", line_number),
        important = M.bool_from_csv(get_column("important")),
        takes_per_style = M.parse_optional_positive_integer(get_column("takes_per_style"), "takes_per_style", line_number),
        section = M.trim(get_column("section")),
        style_hint = M.trim(get_column("style_hint")),
        notes = M.trim(get_column("notes")),
      }

      if seen_phrase_ids[row.phrase_id] then
        handle:close()
        M.fail(string.format("Line %d: duplicate phrase_id '%s'", line_number, row.phrase_id))
      end
      seen_phrase_ids[row.phrase_id] = true

      rows[#rows + 1] = row
    end
  end

  handle:close()

  if #rows == 0 then
    M.fail("CSV contains no data rows")
  end

  return {
    path = path,
    headers = header_fields,
    header_lookup = header_lookup,
    rows = rows,
  }
end

function M.expected_takes_for_row(row)
  if row.takes_per_style then
    return row.takes_per_style
  end
  if row.important then
    return 2
  end
  return 1
end

function M.format_region_name(phrase_id, text)
  return string.format("%s | %s", phrase_id, text)
end

function M.parse_region_name(name)
  local phrase_id, transcript = tostring(name or ""):match("^%s*([^|]+)%s+|%s+(.-)%s*$")
  if not phrase_id or not transcript then
    return nil
  end
  return {
    phrase_id = M.trim(phrase_id),
    transcript = M.trim(transcript),
  }
end

function M.region_sorter(a, b)
  if a.start_pos ~= b.start_pos then
    return a.start_pos < b.start_pos
  end
  if a.end_pos ~= b.end_pos then
    return a.end_pos < b.end_pos
  end
  return a.index_number < b.index_number
end

function M.track_sorter(a, b)
  return a.track_index < b.track_index
end

function M.example_sorter(a, b)
  if a.item_position ~= b.item_position then
    return a.item_position < b.item_position
  end
  if a.lane_index ~= b.lane_index then
    return a.lane_index < b.lane_index
  end
  if a.item_number ~= b.item_number then
    return a.item_number < b.item_number
  end
  return a.take_ordinal < b.take_ordinal
end

function M.style_token(raw)
  local text = M.lower_trim(raw)
  text = text:gsub("%s+", "_")
  text = text:gsub("[^%w_%-]", "_")
  text = text:gsub("_+", "_")
  text = text:gsub("^_+", "")
  text = text:gsub("_+$", "")
  if text == "" then
    M.fail(string.format("Track name '%s' normalizes to an empty style token", tostring(raw or "")))
  end
  return text
end

function M.choose_csv_file(title)
  local ok, path = reaper.GetUserFileNameForRead("", title or "Choose CSV file", ".csv")
  if not ok then
    return nil
  end
  return path
end

function M.prompt_import_settings()
  local ok, values = reaper.GetUserInputs(
    "Voice Dataset Import",
    4,
    "Clear existing dataset regions (0/1),Gap seconds,Create guide track (0/1),Create section markers (0/1)",
    "1,0.5,1,1"
  )

  if not ok then
    return nil
  end

  local clear_text, gap_text, guide_text, section_text =
    values:match("([^,]*),([^,]*),([^,]*),([^,]*)")

  local gap_seconds = tonumber(M.trim(gap_text))
  if not gap_seconds or gap_seconds < 0 then
    M.fail("Gap seconds must be zero or greater")
  end

  return {
    clear_existing = (tonumber(M.trim(clear_text)) or 0) >= 0.5,
    gap_seconds = gap_seconds,
    create_guide_track = (tonumber(M.trim(guide_text)) or 0) >= 0.5,
    create_section_markers = (tonumber(M.trim(section_text)) or 0) >= 0.5,
  }
end

function M.get_project_path()
  local path = reaper.GetProjectPath("")
  return path or ""
end

function M.prompt_render_settings(default_output_dir)
  local ok, values = reaper.GetUserInputs(
    "Voice Dataset Render",
    3,
    "Output directory,Dry run only (0/1),Use only unmuted named tracks (0/1)",
    table.concat({
      default_output_dir or "",
      "1",
      "1",
    }, ",")
  )

  if not ok then
    return nil
  end

  local output_dir, dry_run_text, unmuted_text = values:match("([^,]*),([^,]*),([^,]*)")
  output_dir = M.trim(output_dir)
  if output_dir == "" then
    M.fail("Output directory cannot be blank")
  end

  return {
    output_dir = output_dir,
    dry_run = (tonumber(M.trim(dry_run_text)) or 0) >= 0.5,
    unmuted_only = (tonumber(M.trim(unmuted_text)) or 0) >= 0.5,
  }
end

function M.build_row_lookup(rows)
  local lookup = {}
  for _, row in ipairs(rows) do
    lookup[row.phrase_id] = row
  end
  return lookup
end

function M.get_track_name(track)
  local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  return M.trim(name)
end

function M.collect_named_style_tracks(unmuted_only)
  local tracks = {}
  local blank_named_tracks = {}

  for track_index = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, track_index)
    local name = M.get_track_name(track)
    local item_count = reaper.CountTrackMediaItems(track)
    if name == "" then
      if item_count > 0 then
        blank_named_tracks[#blank_named_tracks + 1] = track_index + 1
      end
    elseif name ~= "Teleprompt Guide" then
      local muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") > 0.5
      if not unmuted_only or not muted then
        tracks[#tracks + 1] = {
          track = track,
          track_name = name,
          style_token = M.style_token(name),
          track_index = track_index + 1,
        }
      end
    end
  end

  if #blank_named_tracks > 0 then
    M.fail("Tracks with media items must have names. Blank track indexes: " .. table.concat(blank_named_tracks, ", "))
  end

  table.sort(tracks, M.track_sorter)
  M.require(#tracks > 0, "No style tracks found. Name at least one non-guide track.")
  return tracks
end

function M.collect_regions()
  local marker_count, region_count = reaper.CountProjectMarkers(0)
  local total = marker_count + region_count
  local regions = {}

  for marker_index = 0, total - 1 do
    local ok, is_region, start_pos, end_pos, name, index_number = reaper.EnumProjectMarkers(marker_index)
    if ok and is_region then
      regions[#regions + 1] = {
        marker_index = marker_index,
        index_number = index_number,
        start_pos = start_pos,
        end_pos = end_pos,
        name = name or "",
      }
    end
  end

  table.sort(regions, M.region_sorter)
  return regions
end

function M.find_or_create_track(track_name)
  for track_index = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, track_index)
    if M.get_track_name(track) == track_name then
      return track, false
    end
  end

  local index = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(index, true)
  local track = reaper.GetTrack(0, index)
  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", track_name, true)
  return track, true
end

function M.format_seconds(value)
  return string.format("%.3f", value)
end

function M.metadata_line(filename, transcript)
  return filename .. "|" .. transcript
end

function M.manifest_full_line(entry)
  return table.concat({
    M.csv_escape(entry.filename),
    M.csv_escape(entry.phrase_id),
    M.csv_escape(entry.transcript),
    M.csv_escape(entry.track_name),
    M.csv_escape(entry.take_index),
    M.csv_escape(M.bool_to_string(entry.important)),
    M.csv_escape(entry.expected_takes),
    M.csv_escape(M.format_seconds(entry.region_start)),
    M.csv_escape(M.format_seconds(entry.region_end)),
    M.csv_escape(entry.section),
    M.csv_escape(entry.notes),
  }, ",")
end

function M.missing_takes_line(entry)
  return table.concat({
    M.csv_escape(entry.phrase_id),
    M.csv_escape(entry.track_name),
    M.csv_escape(entry.expected_takes),
    M.csv_escape(entry.actual_takes),
    M.csv_escape(entry.status),
  }, ",")
end

return M
