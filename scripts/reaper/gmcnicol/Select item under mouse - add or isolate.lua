-- @description Select item under mouse - add or isolate
-- @version 1.0
-- @author Codex
-- @about
--   If the item under the mouse is not selected, add it to the selected items.
--   If it is already selected, select only that item.
--   This makes a double tap leave a single selected item.

local SELECT_ITEM_UNDER_MOUSE = 40528
local ADD_ITEM_UNDER_MOUSE = 40529

local x, y = reaper.GetMousePosition()
local item = reaper.GetItemFromPoint(x, y, true)

if not item then return end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

if reaper.IsMediaItemSelected(item) then
  reaper.Main_OnCommand(SELECT_ITEM_UNDER_MOUSE, 0)
else
  reaper.Main_OnCommand(ADD_ITEM_UNDER_MOUSE, 0)
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Select item under mouse - add or isolate", -1)
