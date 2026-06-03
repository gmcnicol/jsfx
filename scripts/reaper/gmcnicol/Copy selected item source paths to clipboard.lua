-- Copies source file path(s) for selected media item takes to the system clipboard.

local function shell_quote(path)
  return "'" .. tostring(path):gsub("'", "'\\''") .. "'"
end

local function set_clipboard(text)
  if reaper.CF_SetClipboard then
    reaper.CF_SetClipboard(text)
    return true
  end

  local tmp_path = reaper.GetResourcePath() .. "/Data/gmcnicol_selected_item_paths_clipboard.txt"
  local file = io.open(tmp_path, "wb")
  if not file then return false end
  file:write(text)
  file:close()

  local ok = os.execute("/usr/bin/pbcopy < " .. shell_quote(tmp_path))
  return ok == true or ok == 0
end

local function take_source_path(take)
  if not take then return nil end

  local source = reaper.GetMediaItemTake_Source(take)
  if not source then return nil end

  if reaper.GetMediaSourceParent then
    local parent = reaper.GetMediaSourceParent(source)
    while parent do
      source = parent
      parent = reaper.GetMediaSourceParent(source)
    end
  end

  local path = reaper.GetMediaSourceFileName(source, "")
  if path and path ~= "" then return path end
  return nil
end

local count = reaper.CountSelectedMediaItems(0)
if count == 0 then
  reaper.ShowMessageBox("No media item selected.", "Copy selected item source paths", 0)
  return
end

local paths = {}
local seen = {}

for i = 0, count - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  local take = item and reaper.GetActiveTake(item)
  local path = take_source_path(take)
  if path and not seen[path] then
    seen[path] = true
    paths[#paths + 1] = path
  end
end

if #paths == 0 then
  reaper.ShowMessageBox("Selected item has no source file path.", "Copy selected item source paths", 0)
  return
end

local text = table.concat(paths, "\n")
if set_clipboard(text) then
  reaper.ShowConsoleMsg("Copied selected item source path")
  if #paths ~= 1 then reaper.ShowConsoleMsg("s") end
  reaper.ShowConsoleMsg(" to clipboard:\n" .. text .. "\n")
else
  reaper.ShowMessageBox("Could not write to clipboard.", "Copy selected item source paths", 0)
end
