--TODO: clean item-with-inventory
--TODO: Implement file format support. "[Rseding91] It can output bmp, jpg, gif, tif, and png."

-- -------------------------------------------------------------------------- --
-- CONSTANTS                                                                  --
-- -------------------------------------------------------------------------- --


local main_gui_frame_name = 'screenshot-hotkey-main-frame'
local selection_tool_name = 'er:screenshot-tool'


local ITEM_NAME = 'er:screenshot-camera'
-- local INPUT_NAME = ITEM_NAME

local erlib = require 'minilib'

local PLUGIN_NAME   = 'screenshot-maker'
local SAVEDATA_PATH = {'plugin_manager', 'plugins', PLUGIN_NAME}

-- -------------------------------------------------------------------------- --
-- X                                                                          --
-- -------------------------------------------------------------------------- --

local Savedata

-- local ScreenshotArea = {}
-- local ScreenshotArea_mt = {__index = ScreenshotArea}
-- 
-- 
-- local ScreenshotPlayer = {}
-- 
-- setmetatable(ScreenshotPlayer, {
--   __call = function(_, pindex)
--     return game.get_player(pindex)
--     end,
--   })
-- 
-- local function get_player_screenshot_area(pindex, index)
--   index = index or 1 --future use: multiple areas per player
--   
--   -- Savedata = global.plugin_manager.plugins['screenshot-maker']
--   
--   -- pdata = erlib.Table.sget(Savedata, {'players', pindex})
--   
--   local new = {
--     p = 
--     }
--   
--   return setmetatable(
--     erlib.Table.sget(Savedata, {'players', pindex, 'screenshot_area', index}, {}),
--     ScreenshotArea_mt
--     )
--   
--   end
  

-- -------------------------------------------------------------------------- --
-- Savedata                                                                   --
-- -------------------------------------------------------------------------- --

local function get_pdata (pindex)
  return erlib.Table.sget(Savedata, {'players', pindex}, {})
  end

local function reset_pdata(pindex)
  local pdata = get_pdata(pindex)
  rendering.destroy(pdata.rect_uid or -1)
  erlib.Table.set(Savedata, {'players', pindex}, {})
  end
  
  
local function init()
  Savedata = erlib.Table.sget(global, SAVEDATA_PATH, {})
  end
  
local function onload()
  Savedata = erlib.Table.get(global, SAVEDATA_PATH)
  end
  
script.on_init(init)
script.on_configuration_changed(init)
script.on_load(onload)


-- -------------------------------------------------------------------------- --
-- Shortcut                                                                   --
-- -------------------------------------------------------------------------- --



local function give_camera_to_player(p)
  if p.clean_cursor() then
    p.cursor_stack.set_stack { name = ITEM_NAME }
    end
  end

script.on_event(ITEM_NAME, function(e)
  print('hotkey!')
  give_camera_to_player(game.get_player(e.player_index))
  end)
  
script.on_event(defines.events.on_lua_shortcut, function(e)
  print('shortcut!')
  if e.prototype_name == ITEM_NAME then
    give_camera_to_player(game.get_player(e.player_index))
    end
  end)
  
  
  
  
-- -------------------------------------------------------------------------- --
-- MAIN                                                                       --
-- -------------------------------------------------------------------------- --

script.on_event(defines.events.on_player_cursor_stack_changed, function(e)
  local p = game.players[e.player_index]
  local cs = p.cursor_stack
  if (not cs.valid_for_read) or (cs.name ~= ITEM_NAME) then
    reset_pdata(e.player_index)
    print('data reset!', serpent.line(get_pdata(e.player_index)) )
    end
  end)


local COLOR_WHITE = {r=1, g=1, b=1}

local function update_rect(rect, uid, p)
  if not rendering.is_valid(uid or -1) then
    uid = rendering.draw_rectangle{
      color = COLOR_WHITE,
      width = 2,
      filled = false,
      left_top = rect.lt,
      right_bottom = rect.rb,
      surface = p.surface,
      time_to_live = 60*2,
      -- time_to_live = 30,
      players = {p},
      visible = true,
      draw_on_ground = false,
      only_in_alt_mode = false,
      }
  else
    rendering.set_left_top    (uid, rect.lt)
    rendering.set_right_bottom(uid, rect.rb)
    end
  return uid
  end

local function blip (target,p)
    local rnd = function() return math.random(100,255) end
    local def = {
      color = {r=rnd(),g=rnd(),b=rnd()},
      radius = 0.2,
      filled = true,
      target = target or env.that or env.it,
      time_to_live = duration or 300,
      surface = p.surface,
      }
    return target,rendering.draw_circle(def) end
  
local function swap_if_gtr(a,b)
  if a <= b then return a,b
  else return b,a end
  end

local function vector_to_natural_rect(v)
  local l,r = swap_if_gtr(v.a,v.x)
  local t,b = swap_if_gtr(v.b,v.y)
  
  return {
    lt = {math.floor(l),math.floor(t)},
    rb = {math.ceil(r),math.ceil(b)},
    }
  end
  
  
script.on_event(defines.events.on_player_used_capsule, function(e)
  -- print(serpent.line(e.position))
  
  local pindex= e.player_index
  local p     = game.get_player(pindex)
  local pdata = get_pdata(pindex)
  
  local clicked_position = e.position
  
  
  if not pdata.vector then
  
    pdata.vector = {}
  
    --cursor-to-rect-distance isn't nice yet.
    -- cursor should always be inside the "dragged" tile.
    
    pdata.vector.a = clicked_position.x
    pdata.vector.b = clicked_position.y
    
    -- pdata.vector.a = 0
    -- pdata.vector.b = 0

    
    pdata.vector.x = clicked_position.x
    pdata.vector.y = clicked_position.y

    pdata.move = {x='x', y='y'}
    
  else --corner pulling of existant rect
  
    --todo: update move keys if axis crossed?
    
    
    end
    
    
  pdata.vector[pdata.move.x] = clicked_position.x
  pdata.vector[pdata.move.y] = clicked_position.y
  
  
  pdata.rect_uid = update_rect(
    vector_to_natural_rect(pdata.vector),
    pdata.rect_uid,
    p
    )
  
  print(
    serpent.line(pdata.vector),
    serpent.line(vector_to_natural_rect(pdata.vector))
    )
    
  -- blip({x=pdata.vector.a,y=pdata.vector.b}, p)
  -- blip({x=pdata.vector.x,y=pdata.vector.y}, p)
    
    
  blip(e.position, p) -- clicked pos
  
  end)
  
  

