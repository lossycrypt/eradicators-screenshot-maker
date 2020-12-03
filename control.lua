--TODO: clean item-with-inventory
--TODO: Implement file format support. "[Rseding91] It can output bmp, jpg, gif, tif, and png."

local main_gui_frame_name = 'screenshot-hotkey-main-frame'
local selection_tool_name = 'er:screenshot-tool'

local function get_camera_settings(pindex)
  global.camera_settings = global.camera_settings or {}
  if not global.camera_settings[pindex] then
    global.camera_settings[pindex] = {w = 2048, h = 2048, zoom = 1.0, camera_tick = -1}
    end
  return global.camera_settings[pindex]
  end

local function get_player_data(e)
  local pindex = e.player_index
  local player = game.players[pindex]
  local pgui   = player.gui.center
  return player,pindex,pgui
  end

local function tointeger(str)
  return math.floor(tonumber(str))
  end

local function area_to_camera_settings(pindex,area)
  local camera_settings = get_camera_settings(pindex)
  --clamp to tile edges
  area.left_top.x     = math.floor(area.left_top.x    )
  area.left_top.y     = math.floor(area.left_top.y    )
  area.right_bottom.x = math.ceil (area.right_bottom.x)
  area.right_bottom.y = math.ceil (area.right_bottom.y)
  -- calculate width/height in pixels and center position
  camera_settings.w = area.right_bottom.x - area.left_top.x
  camera_settings.h = area.right_bottom.y - area.left_top.y
  camera_settings.x = area.left_top.x + camera_settings.w/2
  camera_settings.y = area.left_top.y + camera_settings.h/2
  camera_settings.w = camera_settings.w * 32 --one tile is 32 pixels
  camera_settings.h = camera_settings.h * 32
  -- print(serpent.block(camera_settings))
  end

local function openScreenshotGui(player,pindex,pgui,area)
  local camera_settings = get_camera_settings(pindex)
  if area then area_to_camera_settings(pindex,area) end

  --remove old instance
  if pgui[main_gui_frame_name] then
    pgui[main_gui_frame_name].destroy()
    end
  pgui.clear() --HOTFIX: when galactipad is open and ctrl+f12 wants to open Screenshot gui the next add() fails???
  --FRAME
  player.opened = pgui.add {
    type = 'frame',
    name = main_gui_frame_name,
    caption = {'screenshot-hotkey.title'},
    direction = 'vertical',
  }
  print(serpent.line(player.opened))
  print(serpent.line(player.gui.center.children_names))
  local pmain = pgui[main_gui_frame_name]
  --INFO
  for i=1,5 do
    pmain.add {
      type = 'label',
      name = 'info'..i,
      caption = {'screenshot-hotkey.info'..i},
    }
    end

  --TABLE
  pmain.add {
    type = 'table',
    name = 'table',
    -- colspan = 2, --pre 0.16
    column_count = 2,
  }
  pmain = pmain.table

  --TABLE CONTENT TEXTFIELD
  local labels = {'xres','yres','xpos','ypos','scale','file'} -- renamed "zoom" to "scale" due to name collision with base function
  for i=1,#labels do
    pmain.add {
      type = 'label',
      name = labels[i],
      caption = {'screenshot-hotkey.'..labels[i]},
      }
    pmain.add {
      type = 'textfield',
      name = labels[i]..'_text',
      }
    end

  --TABLE CONTENT BOOLEAN
  local bools = {'show_info','anti_alias','show_gui'}
  for i=1,#bools do
    pmain.add {
      type = 'label',
      name = bools[i],
      caption = {'screenshot-hotkey.'..bools[i]},
      }
    pmain.add {
      type = 'checkbox',
      name = bools[i]..'_bool',
      state = false,
      }
    end
  -- button take
  pmain.add {
    type = 'button',
    name = 'screenshot-hotkey-quit-button',
    caption = {'screenshot-hotkey.quit'},
  }
  -- button quit
  pmain.add {
    type = 'button',
    name = 'screenshot-hotkey-take-button',
    caption = {'screenshot-hotkey.take'},
  }

  
  pmain['xres_text'    ].text = camera_settings.w 
  pmain['yres_text'    ].text = camera_settings.h
  pmain['xpos_text'    ].text = camera_settings.x or math.floor(player.position.x)
  pmain['ypos_text'    ].text = camera_settings.y or math.floor(player.position.y)
  pmain['scale_text'   ].text = camera_settings.zoom
  pmain['file_text'].text = 'screenshot_'..game.tick
  
  pmain['show_info_bool' ].state = true
  pmain['anti_alias_bool'].state = false
  pmain['show_gui_bool'  ].state = false
  -- print('Debug1: '..player.opened.name)
end

local function takeScreenshot(e,camera_settings)
  local player,pindex,pgui = get_player_data(e)
  local args= {}
  
  if not camera_settings then
    local pmain = pgui[main_gui_frame_name].table
    args.zoom = tonumber (pmain['scale_text'   ].text) --may be decimal
    args.xpos = tonumber (pmain['xpos_text'    ].text)
    args.ypos = tonumber (pmain['ypos_text'    ].text)
    args.xres = tointeger(pmain['xres_text'    ].text) * args.zoom --compensate manul zoom override
    args.yres = tointeger(pmain['yres_text'    ].text) * args.zoom
    args.file =           pmain['file_text'].text
    args.show =           pmain['show_info_bool' ].state
    args.anti =           pmain['anti_alias_bool'].state
    args.gui  =           pmain['show_gui_bool'].state
  else
    args.xpos = camera_settings.x
    args.ypos = camera_settings.y
    args.xres = camera_settings.w
    args.yres = camera_settings.h
    args.zoom = 1.0
    args.file = 'screenshot_'..game.tick
    args.show = true
    args.anti = false
    args.gui  = false
    end
  
  -- check input validity
  local ranges = {
    xpos = {-1e6,1e6}, --maximum map size
    ypos = {-1e6,1e6},
    xres = args.anti and {1,8192} or {1,16384} , --limited by API
    yres = args.anti and {1,8192} or {1,16384} ,
    zoom = {0.05,1000}, --prevent freezes
    }
  for _,arg in pairs{'xres','yres','xpos','ypos','zoom'} do
    if   (args[arg] == nil)
      or (args[arg] < ranges[arg][1])
      or (args[arg] > ranges[arg][2])
      then
      player.print({'screenshot-hotkey.wrong-value',{'screenshot-hotkey.'..arg}})
      return
      end
    end

  -- take screenshot
  game.take_screenshot{
    player           = player                , --:: string or LuaPlayer or uint (optional): Center position on this player?
    by_player        = player                , --:: string or LuaPlayer or uint (optional): If defined, the screenshot will only be taken for this player.
    position         = {args.xpos,args.ypos} , --:: Position (optional)
    resolution       = {args.xres,args.yres} , --:: Position (optional)
    zoom             = args.zoom             , --:: double (optional)
    path             = args.file..'.png'     , --:: string (optional): Path to save the screenshot in
    show_gui         = args.gui              , --:: boolean (optional): Include game GUI in the screenshot?
    show_entity_info = args.show             , --:: boolean (optional): Include entity info (alt-mode)?
    anti_alias       = args.anti             , --:: boolean (optional): Render in double resolution and scale down (including GUI)? 
    }
    
  -- close gui (only if camera settings were not given)
  if pgui[main_gui_frame_name] then
    pgui[main_gui_frame_name].destroy()
    end
  -- save camera settings
  local camera_settings = get_camera_settings(pindex)
  camera_settings = {
    w = args.xres, h = args.yres,
    -- x = args.xpos, y = args.ypos, --never store position
    zoom = args.zoom}
  -- play sound to indicate everything went fine
  player.play_sound{
    path = 'er:camera-click',
    volume_modifier = 0.9,
    }
end

local function toggleScreenshotGui(e)
  local player,pindex,pgui = get_player_data(e)
  if pgui[main_gui_frame_name] then
    pgui[main_gui_frame_name].destroy()
  else
    openScreenshotGui(player,pindex,pgui)
    end
end
  
local function closeScreenshotGui(e)
  local player,pindex,pgui = get_player_data(e)
  if pgui[main_gui_frame_name] then
    pgui[main_gui_frame_name].destroy()
    end
  end

-- ON EVENT
script.on_event('er:screenshot-hotkey',toggleScreenshotGui)
script.on_event(defines.events.on_gui_closed,closeScreenshotGui)

local guiclicks = {['screenshot-hotkey-take-button'] = takeScreenshot      ,
                   ['screenshot-hotkey-quit-button'] = closeScreenshotGui ,}
script.on_event(defines.events.on_gui_click, function(e)
  if guiclicks[e.element.name] then guiclicks[e.element.name](e) end
  -- local f = guiclicks[e.element.name] if f then f(e) end
  end)

--PLAYER USED CAMERA TOOL
script.on_event(defines.events.on_player_selected_area,function(e)
  if e.item ~= selection_tool_name then return end
  local player,pindex,pgui = get_player_data(e)
  openScreenshotGui(player,pindex,pgui,e.area)
  end)

--PLAYER USED CAMERA TOOL (ALT MODE)
script.on_event(defines.events.on_player_alt_selected_area,function(e)
  if e.item ~= selection_tool_name then return end
  local player,pindex,pgui = get_player_data(e)
  local camera_settings = get_camera_settings(pindex)
  area_to_camera_settings(pindex,e.area)
  takeScreenshot(e,camera_settings)
  end)
  
--PLAYER WANTS CAMERA TOOL
script.on_event('er:screenshot-tool',function(e)
  local player,pindex,pgui = get_player_data(e)
  if player.cursor_stack.valid_for_read --give only one tool
    and (player.cursor_stack.name == selection_tool_name)
    then return end
  if player.clean_cursor() then
    player.cursor_stack.set_stack(selection_tool_name)
    local camera_settings = get_camera_settings(pindex)
    camera_settings.camera_tick = e.tick
    end
  end)
  
--PURGE CAMERA TOOL FROM INVENTORY (deprecated in 0.17+)
--[[
script.on_event({'er:controls:clean-cursor', --must work when inventory full!
  defines.events.on_player_cursor_stack_changed}, function(e)
  local player,pindex,pgui = get_player_data(e)
  local camera_settings = get_camera_settings(pindex)
  --prevent deleting in the same tick it is created
  if camera_settings.camera_tick == e.tick then return end
  --clean cursor stack
  if player.cursor_stack.valid_for_read
    and (player.cursor_stack.name == selection_tool_name)
    then player.cursor_stack.clear() end
  --clean opened entitiy
  if player.opened and (player.opened_gui_type == defines.gui_type.entity) then
    player.opened.remove_item{name=selection_tool_name,count=4e9}
    end
  --clean player inventories (main+toolbar)
  player.remove_item{name=selection_tool_name,count=4e9}
  --clean player trash slots
  local trash = player.get_inventory(defines.inventory.player_trash)
  if trash then
    trash.remove{name=selection_tool_name,count=4e9}
    end
  --clean items with inventory?
  --clean selected entity? (ctrl+click quick filling)
  --clean item dropped on belt?
  end)
]]
  
script.on_event(defines.events.on_player_dropped_item,function(e)
  local player,pindex,pgui = get_player_data(e)
  if e.entity.stack and (e.entity.stack.name == selection_tool_name) then
    e.entity.destroy()
    end
  end)
  
  
  
  