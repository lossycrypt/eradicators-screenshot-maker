--TODO: clean item-with-inventory
--TODO: Implement file format support. "[Rseding91] It can output bmp, jpg, gif, tif, and png."

-- -------------------------------------------------------------------------- --
-- CONSTANTS                                                                  --
-- -------------------------------------------------------------------------- --


local main_gui_frame_name = 'screenshot-hotkey-main-frame'
local selection_tool_name = 'er:screenshot-tool'


local ITEM_NAME = 'er:screenshot-camera'
-- local INPUT_NAME = ITEM_NAME

local ITEM_NAME2 = ITEM_NAME .. '-2'

local erlib = require 'minilib'

local SelectionRectangle = require 'SelectionRectangle'

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
  rendering.destroy(pdata.rect_uid or -1) --legacy
  if pdata.selection_rectangle then
    pdata.selection_rectangle:reset()
    end
  erlib.Table.clear(pdata)
  end
  
  
local function init()
  Savedata = erlib.Table.sget(global, SAVEDATA_PATH, {})
  end
  
local function onload()
  Savedata = erlib.Table.get(global, SAVEDATA_PATH)
  for _, pdata in pairs(Savedata.players) do
    if pdata.selection_rectangle then
      SelectionRectangle.reclassify(pdata.selection_rectangle)
      end
    end
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
      time_to_live = nil, --infinite
      -- time_to_live = 60*2,
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

local function update_corners(pdata, p)
  for i = 1, 4 do
  
  
    end
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
    lt = {x = math.floor(l), y = math.floor(t)},
    rb = {x = math.ceil (r), y = math.ceil (b)},
    }
  end
  
local function start_new_rect(pdata, position)
  pdata.vector = {
    a = position.x,
    b = position.y,
    x = position.x,
    y = position.y,
    }
  pdata.rect = vector_to_natural_rect(pdata.vector)
  end
  
local function isPointInRect(point, rect)
  if  (rect.lt.x < point.x) and (rect.rb.x > point.x)
  and (rect.lt.y < point.y) and (rect.rb.y > point.y)
    then return true
    else return false
    end
  end
  
local function PointToRect(point, radius)
  -- radius = radius or 0.75
  radius = radius or 1.25
  return {
    lt = {x = point.x - radius, y = point.y - radius},
    rb = {x = point.x + radius, y = point.y + radius},
    }
  end
  
local function RectStretch(rect, offset)
  return {
    lt = {x = rect.lt.x - offset, y = rect.lt.y - offset},
    rb = {x = rect.rb.x + offset, y = rect.rb.y + offset},
    }
  end
  
  
local function on_capsule_v2(e)
  
  if e.item.name ~= ITEM_NAME then return end
  
  local pindex= e.player_index
  local p     = game.get_player(pindex)
  local pdata = get_pdata(pindex)
  
  if not pdata.selection_rectangle then
    pdata.selection_rectangle = SelectionRectangle.new(pindex)
  else
    SelectionRectangle.reclassify(pdata.selection_rectangle)
    end
  
  pdata.selection_rectangle:click(e.position)
  
  
  end
  

  
local function on_capsule_v1 (e)
  -- print(serpent.line(e.position))
  
  local pindex= e.player_index
  local p     = game.get_player(pindex)
  local pdata = get_pdata(pindex)
  
  local clicked_position = e.position
  
  
  
  
  -- init new
  -- if (not pdata.vector) or (not isPointInRect(clicked_position, RectStretch(pdata.rect, 5))) then
  if (not pdata.vector) then
  
    if pdata.rect then
      print('new!')
      print(serpent.line(clicked_position), serpent.line(RectStretch(pdata.rect, 1)))
      print( isPointInRect(clicked_position, RectStretch(pdata.rect, 1)) )
      end
      
    if not pdata.vector then
      print('no vector')
      end
    
    reset_pdata(pindex)
    start_new_rect(pdata, clicked_position)
    
    -- active corner
    pdata.move = {
      x = 'x',
      y = 'y',
      }


  -- 
  else

    --left top
    if isPointInRect(clicked_position, PointToRect{x=pdata.rect.lt.x, y=pdata.rect.lt.y}) then
      pdata.vector.a = pdata.rect.rb.x
      pdata.vector.b = pdata.rect.rb.y
      
    --right top
    elseif isPointInRect(clicked_position, PointToRect{x=pdata.rect.rb.x, y=pdata.rect.lt.y}) then
      pdata.vector.a = pdata.rect.lt.x
      pdata.vector.b = pdata.rect.rb.y
    
    --right bottom
    elseif isPointInRect(clicked_position, PointToRect{x=pdata.rect.rb.x, y=pdata.rect.rb.y}) then
      pdata.vector.a = pdata.rect.lt.x
      pdata.vector.b = pdata.rect.lt.y
    
    --left bottom
    elseif isPointInRect(clicked_position, PointToRect{x=pdata.rect.lt.x, y=pdata.rect.rb.y}) then
      pdata.vector.a = pdata.rect.rb.x
      pdata.vector.b = pdata.rect.lt.y
      
      end
  
  
  
    -- if not isPointInRect(pdata.rect, clicked_position)
  
  
  
  -- corner pulling of existant rect
  
  
  
    --todo: update move keys if axis crossed?
    
    
    end
    
    
    
    
  pdata.vector[pdata.move.x] = clicked_position.x
  pdata.vector[pdata.move.y] = clicked_position.y
  
  pdata.rect = vector_to_natural_rect(pdata.vector)
  
  pdata.rect_uid = update_rect(
    pdata.rect,
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
  
  end
  
  

-- script.on_event(defines.events.on_player_used_capsule, on_capsule_v1)
script.on_event(defines.events.on_player_used_capsule, on_capsule_v2)
  