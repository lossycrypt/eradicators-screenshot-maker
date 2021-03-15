--TODO: clean item-with-inventory
--TODO: Implement file format support. "[Rseding91] It can output bmp, jpg, gif, tif, and png."

--[[ Concept:

  + A drag-drop movable and resizable area selection tool to select
    parts of the factory to take screenshots of.
    + Resizing works like in gimp
  
--]]

--[[ Future:

    Engine Bugs (new/fixed):
      + LuaGuiElement "switch" does not fire events after loading.
        + broken in 1.0, fixed in 1.1
      + Using the built-in spawning mechanism of shortcuts sometimes doens't work.
        + Can't be bothered to make a bug report right now. From memory
        + pressing the hotkey didn't work? because it requires spawning in the
          hotkey prototype too?!

    Engine Bugs (reported):
      + Quick-put (Ctrl+LMB) can be used to put the camera into objects
        + even if the object has no inventory! (like stone-rock)
        + even if the object is out of reach!
        ? uncertain reproducibility without mods
        @ https://forums.factorio.com/viewtopic.php?f=7&t=93071
      + player sound without position is zoom dependant
        @ https://forums.factorio.com/viewtopic.php?f=7&t=93067
      + notched slider has no tooltip for the slider itself only the bar.
        @ https://forums.factorio.com/viewtopic.php?p=527432#p527432
      + Assigning a new style via style = 'name' to a LuaGuiElement
        that has style overrides makes the element lose all 
        override values after save/load even though it works during runtime.
        @ https://forums.factorio.com/viewtopic.php?f=7&t=93070

    Modportal:
      + Animated gif that shows the gui and a factory scene,
        cycling though the different advanced options
        alt+time, alt, time, neither
      + Animated gif showing draw+resize+move

    Future Mod Settings:
      + Maximum zoomout (for slow machines)


    Features:
      + Add a watermark to (large) screenshots :p (with mod option to disable)
        + Advanced option "Watermark show/hide"
        + lower right corner?
        + "by $player-name (made with Eradicator's Screenshot Maker)"
        
      + make SelectionRectangle a library compatible module
      + general code cleanup

    Large Features:
      + allow creating tiled screenshot for very large areas
        + auto-create a .cmd file that uses image-magick to stich them together?
          + mod setting, default disabled
          + maybe someone can supply a linux version? (or is that the same code?)
        + visual effect to indicate which tile is currently being processed?
      + use of 1.1 api features
        + selection of multiple canvas frames
        + RMB deletes the clicked frame
        + take picture with middle-click?
        + MMB inside to activate/select canvas
        + MMB outside of any frame reverts to full-screen mode(?)
        + drawing outside selection rectangle starts new selection
        + Named areas, file pattern %name%
      + Option: Area Size (absolute/relative)
        + Relative resizes the area when the player zooms in/out.
        + Absolute is standard mode.
      + Super-Screenshot-Mode
        ? This should be the default mode, but is an optional "normal" mode needed?
        + controller gui is hidden temporarily
          + logically conflicts with "show gui".
        + Character is detached and player becomes god (spectator?)
        + zoom is fully linked
        + mouse-wheel to resize the currently-hovered canvas?
      + Transparent background option
        + copy stuff to new surface with transparent background
        + (Using build-from blueprint to exclude trees?) -> Nope, KISS
    
    
    Rejected features:
      - allow changing selection snappiness
        - feature creep, fully reimplementing
          blueprint-style grid snapping isn't worth it.
      - dynamic canvas-size timelapse
        - there are other mods
        + static size timelapse might be ok
      - keep it simple
        - read alt-info directly from player
        - show selection rectangle drag indicators
        - location snapping when dragging the gui
        - store gui location
        - in-world clickable buttons


        
--]]

-- -------------------------------------------------------------------------- --
-- Imports                                                                    --
-- -------------------------------------------------------------------------- --

local erlib  = require 'control/erlib-mini'
local Table  = erlib.Table


local SelectionRectangle = require 'control/SelectionRectangle'
local ScreenshotGui      = require 'control/ScreenshotGui'
local CONST              = require 'control/constants'

-- -------------------------------------------------------------------------- --
-- Debug                                                                      --
-- -------------------------------------------------------------------------- --
setmetatable(_ENV, {
  __index = function(_, key)
    error('\n\nBlocked global read\n'..serpent.block(key)..'\n')
    end,
  __newindex = function(_, key, value)
    error('\n\nBlocked global write\n'..serpent.block{[key]=value}..'\n')
    end,
  })


-- -------------------------------------------------------------------------- --
-- Savedata (on_load)                                                         --
-- -------------------------------------------------------------------------- --

local Savedata


local function init()
  Savedata = Table.sget(_ENV.global, CONST.SAVEDATA_PATH, {})
  end

  
local function onload()
  Savedata = Table.get(_ENV.global, CONST.SAVEDATA_PATH)
  for _, pdata in pairs(Savedata.players or {}) do
    SelectionRectangle.reclassify(pdata.selection_rectangle)
    ScreenshotGui     .reclassify(pdata.sgui)
    end
  end

  
script.on_init(init)
script.on_configuration_changed(init)
script.on_load(onload)


  
-- -------------------------------------------------------------------------- --
-- Savedata (pdata)                                                           --
-- -------------------------------------------------------------------------- --

-- The full default values for each player
local function get_default_pdata(pindex)
  local p = game.players[pindex]
  return {
    sgui = ScreenshotGui.new(pindex, p),
    selection_rectangle = SelectionRectangle.new(pindex, p),
    player = p,
    }
  end


local function get_pdata (pindex)
  -- Performance: Only create default table when needed.
  return Table.get(Savedata, {'players', pindex})
      or Table.set(Savedata, {'players', pindex}, get_default_pdata(pindex))
  end


  
-- -------------------------------------------------------------------------- --
-- Open / Close Gui (Shortcut + cursor_stack_changed)                         --
-- -------------------------------------------------------------------------- --

-- Can fail to give the player a camera when they have a full inventory.
local function try_give_camera(p)
  return p.clean_cursor()
     and p.cursor_stack.set_stack { name = CONST.ITEM_NAME }
  end


-- Player is *guaranteed* to not have a camera afterwards.
local function take_camera(p)
  local cs = p.cursor_stack
  if cs.valid_for_read and (cs.name == CONST.ITEM_NAME) then
    cs.clear()
    end
  end
  

local function has_player_camera(p)
  local cs = p.cursor_stack
  return (cs) and (cs.valid_for_read) and (cs.name == CONST.ITEM_NAME)
  end


-- local function set_player_game_view_setting(p, key, value)
  -- local gws = p.game_view_settings
  -- local old_value = gws[key]
  -- gws[key] = value
  -- p.game_view_settings = gws
  -- return old_value
  -- end

local gws_keys = {
  'update_entity_selection'       ,
  'show_rail_block_visualisation' ,'show_controller_gui',
  'show_side_menu'                ,'show_minimap'       ,
  'show_map_view_options'         ,'show_research_info' ,
  'show_quickbar'                 ,'show_entity_info'   ,
  'show_shortcut_bar'             ,'show_alert_gui'     ,
  }

local function hide_player_gui(pdata)
  local gws = pdata.player.game_view_settings
  pdata.game_view_settings = {}
  for _, k in pairs(gws_keys) do
    pdata.game_view_settings[k] = gws[k]
    gws[k] = false -- hide everything
    end
  gws.show_controller_gui = true -- but keep cursor_stack visible
  end


local function restore_player_gui(pdata)
  pdata.player.game_view_settings = pdata.game_view_settings
  -- pdata.game_view_settings = nil
  end


-- single-entry-point for opening the gui
local function try_enable_screenshot_mode(pindex)
  local pdata = get_pdata(pindex)
  local p     = pdata.player
  local cs = p.cursor_stack
  if (not cs.valid_for_read) or (cs.name ~= CONST.ITEM_NAME) then
    if try_give_camera(p) then
      hide_player_gui(pdata)      
      p.game_view_settings.update_entity_selection = false
      p.selected = nil
      pdata.sgui:open()
      p.set_shortcut_toggled(CONST.ITEM_NAME, true)
      end
    end
  end


local function disable_screenshot_mode(pindex)
  local pdata = get_pdata(pindex)
  local p     = pdata.player
  pdata.selection_rectangle:reset()
  pdata.sgui:on_player_changed_selected_area(
    {left_top = {x = 0, y = 0}, right_bottom = {x = 0, y = 0}}
    )
  pdata.sgui:close()
  take_camera(p)
  p.set_shortcut_toggled(CONST.ITEM_NAME, false)
  restore_player_gui(pdata)
  -- Compromise: Enforcing true might be incompatible with certain
  -- edge-case mods or scenarios but prevents players from
  -- becoming stuck in an unplayable mode.
  p.game_view_settings.update_entity_selection = true
  end


script.on_event(CONST.ITEM_NAME, function(e)
  -- print('hotkey!')
  try_enable_screenshot_mode(e.player_index)
  end)

  
script.on_event(defines.events.on_lua_shortcut, function(e)
  -- print('shortcut!')
  if e.prototype_name == CONST.ITEM_NAME then
    local pdata = get_pdata(e.player_index)
    if has_player_camera(pdata.player) then
      disable_screenshot_mode(e.player_index)
    else
      try_enable_screenshot_mode(e.player_index)
      end
    end
  end)


-- To minimize processing cost cursor stack changes
-- can only be used to *close* the gui.
script.on_event(defines.events.on_player_cursor_stack_changed, function(e)
  -- print('cursor_stack_changed')
  local pdata = get_pdata(e.player_index)
  if pdata.sgui:is_gui_open() then
    -- local cs = pdata.player.cursor_stack
    -- if (not cs.valid_for_read) or (cs.name ~= CONST.ITEM_NAME) then
    if not has_player_camera(pdata.player) then
      disable_screenshot_mode(e.player_index)
      end
    end
  end)


-- This also triggers at the beginning of a new map.
script.on_event({
  defines.events.on_player_display_resolution_changed,
  defines.events.on_player_display_scale_changed,
  }, function(e)
    local pdata = get_pdata(e.player_index)
    if has_player_camera(pdata.player) then
      pdata.sgui:close()
      pdata.sgui:open()
      end
    end)



-- -------------------------------------------------------------------------- --
-- Capsule                                                                    --
-- -------------------------------------------------------------------------- --

script.on_event(defines.events.on_player_used_capsule, function(e)
  if e.item.name == CONST.ITEM_NAME then
    local pdata = get_pdata(e.player_index)
    pdata.selection_rectangle
      :click(e.position)
      :draw()
    pdata.sgui:on_player_changed_selected_area(
      pdata.selection_rectangle:get_selected_area()
      )
    end
  end)


script.on_event(CONST.EVENT.RIGHT_CLICK, function(e)
  local pdata = get_pdata(e.player_index)
  if has_player_camera(pdata.player) then
    pdata.selection_rectangle:reset()
    pdata.sgui:on_player_changed_selected_area(
      pdata.selection_rectangle:get_selected_area()
      )
    end
  end)


-- -------------------------------------------------------------------------- --
-- Rotate                                                                     --
-- -------------------------------------------------------------------------- --

script.on_event({
  CONST.EVENT.ROTATE_RIGHT,
  CONST.EVENT.ROTATE_LEFT ,
  }, function(e)
  local pdata = get_pdata(e.player_index)
  if has_player_camera(pdata.player) then
    if e.input_name == CONST.EVENT.ROTATE_RIGHT then
      pdata.selection_rectangle:rotate_right():draw()
    else
      pdata.selection_rectangle:rotate_left():draw()
      end
    end
  end)

  
-- -------------------------------------------------------------------------- --
-- Gui Player Input                                                           --
-- -------------------------------------------------------------------------- --

ScreenshotGui.on_event('on_player_clicked_exit_button', function(e)
  disable_screenshot_mode(e.player_index)
  end)


script.on_event({
  -- defines.events.on_gui_checked_state_changed  ,
  defines.events.on_gui_click                  ,
  -- defines.events.on_gui_closed                 ,
  defines.events.on_gui_confirmed              ,
  -- defines.events.on_gui_elem_changed           ,
  -- defines.events.on_gui_location_changed       ,
  -- defines.events.on_gui_opened                 ,
  -- defines.events.on_gui_selected_tab_changed   ,
  defines.events.on_gui_selection_state_changed,
  defines.events.on_gui_switch_state_changed   ,
  defines.events.on_gui_text_changed           ,
  defines.events.on_gui_value_changed          ,
  },
  function(e)
  
    -- -- V1: mod context dependant
    -- -- api doc says: "not-super-expensive but not free"
    -- if e.element.get_mod() == CONST.MOD_NAME then 
    --   get_pdata(e.player_index).sgui
    --     :on_player_clicked_something(e)
    --   end
    
    -- V2: per gui instance
    local sgui = get_pdata(e.player_index).sgui
    if sgui:is_member(e.element) then
      sgui:on_player_clicked_something(e)
      end
      
    end)
