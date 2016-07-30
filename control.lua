local main_gui_frame_name = "screenshot-hotkey-main-frame"
local session_options = {}

-- local function toggleScreenshotGui(player,pindex,pgui)
local function toggleScreenshotGui(player,pindex,pgui)
  session_options[pindex] = session_options[pindex] or {x = 2048, y = 2048, zoom = 1.0}

  if pgui[main_gui_frame_name] then
    pgui[main_gui_frame_name].destroy()
    return
    end
  --FRAME
  pgui.add {
    type = 'frame',
    name = main_gui_frame_name,
    caption = {"screenshot-hotkey.title"},
    direction = 'vertical',
  }
  pmain = pgui[main_gui_frame_name]
  --INFO
  for i=1,3 do
    pmain.add {
      type = 'label',
      name = 'info'..i,
      caption = {"screenshot-hotkey.info"..i},
    }
    end

  --TABLE
  pmain.add {
    type = 'table',
    name = 'table',
    colspan = 2,
  }
  pmain = pmain.table

  --TABLE CONTENT TEXTFIELD
  local labels = {'xres','yres','xpos','ypos','zoom','file'}  
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
    caption = {"screenshot-hotkey.quit"},
  }
  -- button quit
  pmain.add {
    type = 'button',
    name = 'screenshot-hotkey-take-button',
    caption = {"screenshot-hotkey.take"},
  }

  
  pmain['xres_text'    ].text = session_options[pindex].x 
  pmain['yres_text'    ].text = session_options[pindex].y
  pmain['xpos_text'    ].text = player.position.x - (player.position.x % 1)
  pmain['ypos_text'    ].text = player.position.y - (player.position.y % 1)
  pmain['zoom_text'    ].text = session_options[pindex].zoom
  pmain['file_text'].text = 'screenshot_'..game.tick
  
  pmain['show_info_bool' ].state = true
  pmain['anti_alias_bool'].state = false
  pmain['show_gui_bool'  ].state = false

end

local function takeScreenshot(event)
  local pindex = event.player_index
  local player = game.players[pindex]
  local pgui   = player.gui.center
  local pmain  = pgui[main_gui_frame_name].table

  local args = {}
  args.xpos = tonumber(pmain['xpos_text'    ].text)
  args.ypos = tonumber(pmain['ypos_text'    ].text)
  args.xres = tonumber(pmain['xres_text'    ].text)
  args.yres = tonumber(pmain['yres_text'    ].text)
  args.zoom = tonumber(pmain['zoom_text'    ].text)
  args.file =          pmain['file_text'].text
  args.show =          pmain['show_info_bool' ].state
  args.anti =          pmain['anti_alias_bool'].state
  args.gui  =          pmain['show_gui_bool'].state
  
  -- check input validity
  -- because value are 'nil' when number conversion failed pairs() can't iterate over them
  if args.xpos == nil then player.print({"screenshot-hotkey.wrong-value",{"screenshot-hotkey.xpos"}}) return end
  if args.ypos == nil then player.print({"screenshot-hotkey.wrong-value",{"screenshot-hotkey.ypos"}}) return end
  if args.xres == nil then player.print({"screenshot-hotkey.wrong-value",{"screenshot-hotkey.xres"}}) return end
  if args.yres == nil then player.print({"screenshot-hotkey.wrong-value",{"screenshot-hotkey.yres"}}) return end
  if args.zoom == nil then player.print({"screenshot-hotkey.wrong-value",{"screenshot-hotkey.zoom"}}) return end

  -- DEBUG
  -- for n,v in pairs(args) do
    -- print(n..':'..tostring(v)..':'..type(v))
    -- end
  
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
  -- close gui
  pgui[main_gui_frame_name].destroy()
  -- save options for this session
  session_options[pindex] = {x = args.xres, y = args.yres, zoom = args.zoom}
end

local function triggerScreenshotGui (event)
  local pindex = event.player_index
  local player = game.players[pindex]
  local pgui   = player.gui.center
  toggleScreenshotGui(player,pindex,pgui)
end

-- ON EVENT
script.on_event("take-a-screenshot-hotkey",
  function(e)
    triggerScreenshotGui(e)
    end
  )

local guiclicks = {['screenshot-hotkey-take-button'] = takeScreenshot      ,
                   ['screenshot-hotkey-quit-button'] = triggerScreenshotGui ,}

script.on_event(defines.events.on_gui_click,
  function(e)
    local f = guiclicks[e.element.name]
    if f then f(e) end
    end
  )
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  