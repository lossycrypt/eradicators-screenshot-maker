--TODO: clean item-with-inventory
--TODO: Implement file format support. "[Rseding91] It can output bmp, jpg, gif, tif, and png."

--[[ Future:
    
    Bugs:
      + Engine: LuaGuiElement "switch" does not fire events after loading?
    
    Mod Settings
      + Apply zoom to main view (bool)
      + Close after taking screenshot (bool)
      + Default gui location (left/right) (bool: Use right-side gui) (NOPE: go entity_info style)
      + Maximum zoomout (for slow machines)
      
    Features:
      + Move gui class into seperate file
      + right-click deletes selection rectangle
      + drawing outside selection rectangle starts new selection
      + keep selection when tool not held
      + manual zoom factor input
      + when link-zoom is enabled detect zooming and adjust gui?
      + contextual quality slider for jpeg
      + move main_anchor into gui_elements?
      + help menu (expands from clicking [?] left of [x] in title bar)
      + store window location
      + snap window location while moving (4 pixels?)
      + selection rectangle drag indicators
      + hide gui + rectangle for 0.5s to indicate screenshot was made?
      + read alt-info directly from player?
      + show selected area size in tiles
      + think of a good way to remember file name and still allow easy resetting
        + implement placeholders? i.e. %playtime% %tick%
      + prevent entity selection while camera tool in hand
      + redesign interface to look like a standard entity tooltip.
        + make it relative to the minimap
        + use section headers (also makes more space for file name)
        + move tooltips onto section headers
      + seperate "subfolder" text-field
        
--]]

-- -------------------------------------------------------------------------- --
-- CONSTANTS                                                                  --
-- -------------------------------------------------------------------------- --

local Savedata --dynamically linked in on_load

local main_gui_frame_name = 'screenshot-hotkey-main-frame'
local selection_tool_name = 'er:screenshot-tool'

local MOD_NAME = 'eradicators-screenshot-maker'

local ITEM_NAME = 'er:screenshot-camera'
-- local INPUT_NAME = ITEM_NAME

local ITEM_NAME2 = ITEM_NAME .. '-2'

local erlib = require 'minilib'

local String = erlib.String

local SelectionRectangle = require 'SelectionRectangle'


local ScreenshotGui = {}

local PLUGIN_NAME   = 'screenshot-maker'
local SAVEDATA_PATH = {'plugin_manager', 'plugins', PLUGIN_NAME}

local GUI_MAIN_ANCHOR_NAME = 'er:screenshot-camera:main-anchor'

local CONST = {
  GUI = {
    WIDTH = 256,
    },
    
  ZOOM_STEPS = {
    -- natural mouse-wheel zoom order
    1/16, 1/8, 1/4, 1/2, 1, 2, 4
    },
   
  AVERAGE_COMPRESSION_RATIO = {
    -- Derived from minimal in-game testing.
    ['.bmp'] = 1   ,
    ['.png'] = 0.5 ,
    ['.jpg'] = 0.1 ,
    ['.gif'] = 0.15,
    ['.tif'] = 0.7 ,
    },
    
  ALLOWED_FILE_EXTENSIONS = {
    -- drop-down menu order
    '.png', '.bmp', '.jpg', '.gif', '.tif',
    },
  DEFAULT_FILE_EXTENSION_INDEX = 1,
   
  SWITCH_STATE = {
    ['left' ] = false, [false] = 'left' ,
    ['right'] = true , [true ] = 'right',
    }
  
   
  }

  
-- -------------------------------------------------------------------------- --
-- X                                                                          --
-- -------------------------------------------------------------------------- --

-- small circle render for debugging
local rnd = function() return math.random(100,255) end
local function blip (target, p)
  return rendering.draw_circle {
    color = {r=rnd(), g=rnd(), b=rnd()},
    radius = 0.2,
    filled = true,
    target = target,
    time_to_live = 60*2,
    surface = p.surface,
    }
  end


local function zoom_factor_to_zoom_step_index (zoom_factor)
  -- local i, n = 1, #CONST.ZOOM_STEPS
  -- while (i < n) and (CONST.ZOOM_STEPS[i] < zoom_factor) do
    -- i = i + 1
    -- end
  -- return i 

  local k = 1
  for i = 1, #CONST.ZOOM_STEPS do
    if CONST.ZOOM_STEPS[i] <= zoom_factor then
      k = i
      end
    end
  return k
  
  -- for i, factor in pairs(CONST.ZOOM_STEPS) do
    -- if factor == zoom_factor then
      -- return i
      -- end
    -- end
  -- return zoom_factor_to_zoom_step_index (1)
  end
  
local function zoom_step_index_to_zoom_factor (zoom_step_index)
  return CONST.ZOOM_STEPS[zoom_step_index]
  end
  
  
  
local tag_flow_name = 'er:screenshot-maker-gui-tags'
local function get_gui_element_tags(elm)
  local tag_flow = elm[tag_flow_name]
  if tag_flow then
    local ok, tags = serpent.load(tag_flow.caption or '')
    if ok and tags then return tags end
    end
  return {}
  end

local function set_gui_element_tag(elm, key, value)
  local tags = get_gui_element_tags(elm)
  tags[key] = value
  local tag_flow = elm[tag_flow_name] or elm.add{type='empty-widget',visible=false,name=tag_flow_name}
  tag_flow.caption = serpent.line(tags, {compact=true,nocode=true})
  end
  
local update_handler_tag_name = 'er:screenshot-maker-gui-update-handler'
local function set_gui_element_update_handler(elm, name)
  local tag =
    elm[update_handler_tag_name]
    or elm.add{type='empty-widget',visible=false,name=update_handler_tag_name}
  tag.caption = name
  end
  
local function get_gui_element_update_handler(elm)
  local tag = elm[update_handler_tag_name]
  if tag then return tag.caption end -- nil if none
  end

local function tick_to_playtime_string(tick)
  -- regrettably ":" colon isn't valid for windows filenames
  local h, m, s =
    math.floor(tick / (60^3)),
    math.floor(tick % (60^2) / 60),
    tick % 60
  return (('%3dh_%2dm_%2ds'):format(h, m, s):gsub(' ','0'))
  end
  
-- -------------------------------------------------------------------------- --
-- Savedata                                                                   --
-- -------------------------------------------------------------------------- --



local function init()
  Savedata = erlib.Table.sget(global, SAVEDATA_PATH, {})
  end
  

local function onload()
  Savedata = erlib.Table.get(global, SAVEDATA_PATH)
  for _, pdata in pairs(Savedata.players or {}) do
    if pdata.selection_rectangle then
      SelectionRectangle.reclassify(pdata.selection_rectangle)
      end
    end
  end
  

script.on_init(init)
script.on_configuration_changed(init)
script.on_load(onload)



-- -------------------------------------------------------------------------- --
-- pdata                                                                      --
-- -------------------------------------------------------------------------- --

local function get_pdata (pindex)
  return erlib.Table.sget(Savedata, {'players', pindex}, {
    --default gui state
    gui_state = {
      -- indexes
      -- zoom_step_index = zoom_factor_to_zoom_step_index(1),
      zoom_factor = 1, -- actual state is a string!
      file_extension_index = CONST.DEFAULT_FILE_EXTENSION_INDEX,
      file_name = 'screenshot_%playtime%',
      
      -- bool switches (left:false, right:true)
      show_interface_switch_state = 'left',
      show_alt_info_switch_state = 'right',
      enable_anti_aliasing_switch_state = 'left',
      
      -- trinary switches
      daytime_switch_state = 'none',
      },
    -- LuaGuiElements that need to be read from / written to.
    gui_elements = {
      anchor = nil, --@future
      
      camera = nil,
      
      zoom_slider = nil,
      zoom_text_field = nil,
      resolution_label = nil,
      
      file_name_text_field = nil,
      file_extension_drop_down = nil,
      file_size_label = nil,
      
      show_interface_switch = nil,
      show_alt_info_switch = nil,
      enable_anti_aliasing_switch = nil,
      daytime_switch = nil,
      
      },
    })
  end


local function reset_pdata(pindex)
  local pdata = get_pdata(pindex)
  -- rendering.destroy(pdata.rect_uid or -1) --legacy
  if pdata.selection_rectangle then
    pdata.selection_rectangle:reset()
    end
  -- erlib.Table.clear(pdata, {'zoom'}) --keep
  end

  
  
-- -------------------------------------------------------------------------- --
-- Shortcut                                                                   --
-- -------------------------------------------------------------------------- --

-- Bug: As of 1.0 using the built-in shortcut item spawning feature
-- has some edge cases that don't properly spawn the item. And i'm not
-- in the mood to write them all down properly now >_>.

local function give_camera_to_player(p)
  if p.clean_cursor() then
    p.cursor_stack.set_stack { name = ITEM_NAME }
    end
  local pdata = get_pdata(p.index)
  if not pdata.selection_rectangle then
    pdata.selection_rectangle = SelectionRectangle.new(p.index)
    end
  end

  
script.on_event(ITEM_NAME, function(e)
  -- print('hotkey!')
  give_camera_to_player(game.get_player(e.player_index))
  end)

  
script.on_event(defines.events.on_lua_shortcut, function(e)
  -- print('shortcut!')
  if e.prototype_name == ITEM_NAME then
    give_camera_to_player(game.get_player(e.player_index))
    end
  end)



-- -------------------------------------------------------------------------- --
-- Capsule                                                                    --
-- -------------------------------------------------------------------------- --

-- reset when player is not holding the camera
script.on_event(defines.events.on_player_cursor_stack_changed, function(e)
  -- @future: Restructure so that gui:close doesn't have to be called
  -- on every cursor_stack change.
  local p = game.players[e.player_index]
  local cs = p.cursor_stack
  if (not cs.valid_for_read) or (cs.name ~= ITEM_NAME) then
    reset_pdata(e.player_index)
    -- print('data reset!', serpent.line(get_pdata(e.player_index)) )
    ScreenshotGui.get(e.player_index):close()
  else
    ScreenshotGui.get(e.player_index):open()
    end
  end)

  
local function on_capsule(e)
  
  if e.item.name ~= ITEM_NAME then return end
  
  local pindex= e.player_index
  local p     = game.get_player(pindex)
  local pdata = get_pdata(pindex)
  
  -- print('clicked', serpent.line(e.position))
  
  pdata.selection_rectangle
    :click(e.position)
    :draw()
    
  local sgui = ScreenshotGui.get(e.player_index)
    :on_player_changed_selection_rectangle()
  
    
  end

script.on_event(defines.events.on_player_used_capsule, on_capsule)


-- -------------------------------------------------------------------------- --
-- Gui Creation                                                               --
-- -------------------------------------------------------------------------- --

local ScreenshotGui_mt = {__index = ScreenshotGui}

function ScreenshotGui.get(pindex)
  -- @future: optimize to not always create a new table
  -- because this happens on every cursor_stack change
  local p = game.get_player(pindex)
  return setmetatable({
    player = p,
    pdata  = get_pdata(pindex),
    }
    ,ScreenshotGui_mt)
  end

function ScreenshotGui:get_main_anchor()
  local main_anchor = self.pdata.main_anchor
  if main_anchor and main_anchor.valid then
    return main_anchor
    end
  main_anchor = self.player.gui.screen[GUI_MAIN_ANCHOR_NAME]
  if main_anchor and main_anchor.valid then
    self.pdata.main_anchor = main_anchor
    return main_anchor
    end
  
  self.pdata.main_anchor = self.player.gui.screen.add{
    type = 'frame',
    style = 'outer_frame',
    name = GUI_MAIN_ANCHOR_NAME,
    direction = 'vertical',
    }
  
  return self.pdata.main_anchor
  end

function ScreenshotGui:open()

  local main_anchor = self:get_main_anchor()
  local gui_elements = {}; self.pdata.gui_elements = gui_elements
  
  main_anchor.style.width = CONST.GUI.WIDTH
  -- main_anchor.style.height = 512
  
  -- @future: mod option "default position"
  -- left
  main_anchor.location = {0,48}
  -- right
  main_anchor.location = {self.player.display_resolution.width - CONST.GUI.WIDTH,0}
  
  main_anchor.clear()
  
  -- Title bar with drag handle and close button
  do
    local title_bar_frame = main_anchor.add{
      type = 'frame',
      style = 'inner_frame_in_outer_frame',
      }
    title_bar_frame.drag_target = main_anchor
    title_bar_frame.style.height = 40
    
    local title_bar_flow = title_bar_frame.add{
      type = 'flow',
      direction = 'horizontal',
      }
    title_bar_flow.drag_target = main_anchor
      
    local title_text = title_bar_flow.add{
      type = 'label',
      caption = 'Screenshot',
      style = 'frame_title',
      }
    title_text.ignored_by_interaction = true
      
    local drag_handle = title_bar_flow.add {
      type = 'empty-widget',
      style = 'draggable_space_header',
      }
      
    drag_handle.style.height = 24
    drag_handle.style.horizontally_stretchable = true
    drag_handle.style.right_margin = 4
    drag_handle.ignored_by_interaction = true
    
    local help_button = title_bar_flow.add{
      -- name                = 'dummy-name',
      tooltip = 'Drag-select an area to take a screenshot of.',
      type                = 'button'       ,
      style               = 'frame_action_button' ,
      -- sprite              = 'utility/close_white' ,
      -- hovered_sprite      = 'utility/close_black' ,
      -- clicked_sprite      = 'utility/close_black' ,
      caption = '[font=default-bold][color=white]?[/color][/font]',
      mouse_button_filter = {'left'}              ,
      }
    
    local close_button = title_bar_flow.add{
      name                = 'dummy-name',
      type                = 'sprite-button'       ,
      style               = 'frame_action_button' ,
      sprite              = 'utility/close_white' ,
      hovered_sprite      = 'utility/close_black' ,
      clicked_sprite      = 'utility/close_black' ,
      mouse_button_filter = {'left'}              ,
      }
    set_gui_element_update_handler(close_button, 'close')
    
    --  Titlebar flow:
    --      A horizontal_flow with the default style.
    --      For draggable windows, set this element's drag_target to the window frame.
    --  Title text:
    --      A label that uses the frame_title style.
    --      Only capitalize the first word in the title - all other words should be lowercase.
    --          Exceptions can be made for mod names.
    --      Set ignored_by_interaction to true to facilitate dragging.
    --  Drag handle (for draggable windows):
    --      An empty-widget set to the draggable_space_header style.
    --          height set to 24
    --          horizontally_stretchable set to true
    --          right_margin set to 4.
    --      Set ignored_by_interaction to true to facilitate dragging.
      
    end
    
  -- CAMERA + ZOOM + RESOLUTION
  do 
    local this_frame = main_anchor.add {
      type = 'frame',
      style = 'inner_frame_in_outer_frame',
      direction = 'vertical',
      }
    this_frame.drag_target = main_anchor
    this_frame.style.width = CONST.GUI.WIDTH
    this_frame.style.height = 256 + 24 * 2 - 4
    
    local camera = this_frame.add {
      type = 'camera',
      position = self.player.position,
      surface_index = nil, --defaults to player
      zoom = self.pdata.gui_state.zoom_factor,
      }
    camera.style.width = 232
    camera.style.height = 232
    
    gui_elements.camera = camera
    
    local zoom_flow = this_frame.add {
      type = 'table',
      column_count = 3,
      -- column_alignments = {},
      }
      
    local zoom_label = zoom_flow.add {
      type = 'label',
      caption = 'Zoom [img=info]',
      tooltip = '1 : Normal Resolution\n2 : High Resolution',
      }
      
    local zoom_slider = zoom_flow.add {
      -- "2" is twice zoomed *in*, 0.25 is four times zoomed out.
      -- thus the slider values have to be translated anyway?
      type = 'slider',
      minimum_value = 1,
      maximum_value = #CONST.ZOOM_STEPS,
      value = zoom_factor_to_zoom_step_index(self.pdata.gui_state.zoom_factor),
      -- value_step = 0.125,
      value_step = 1,
      discrete_slider = true,
      discrete_values = true,
      style = 'notched_slider',
      }
    gui_elements.zoom_slider = zoom_slider
      
    
    local zoom_text_field = zoom_flow.add {
      type = 'textfield',
      -- text = ('%f.1'):format(self.pdata.zoom), 
      text = tostring(self.pdata.gui_state.zoom_factor), --can't enforce format because player may enter arbirary values
      numeric = true,
      allow_decimal = true,
      allow_negative = false,
      lose_focus_on_confirm = true,
      clear_and_focus_on_right_click = true,
      }
    gui_elements.zoom_text_field = zoom_text_field
      
    set_gui_element_update_handler(zoom_slider, 'on_player_changed_zoom')
    set_gui_element_update_handler(zoom_text_field, 'on_player_changed_zoom')
    
    zoom_slider.style.horizontally_stretchable = true
    zoom_slider.style.horizontally_squashable = true
    zoom_slider.style.minimal_width = 24
    
    zoom_label.style.height = 16
    zoom_text_field.style.width = 32 + 12
    zoom_text_field.style.height = 24
    zoom_text_field.style.horizontal_align = 'center'
    
    -- zoom_text_field.enabled = false
    
    -- pdata.gui_updaters[zoom_label.index] = 'update_zoom'
    -- pdata.gui_updaters[zoom_slider.index] = 'update_zoom'
    
    -- set_gui_element_tag(zoom_slider, 'update_method', 'update_zoom')
    
    
    -- local selected_area = self.pdata.selection_rectangle:get_selected_area()
    -- local area_width  = selected_area.right_bottom.x - selected_area.left_top.x
    -- local area_height = selected_area.right_bottom.y - selected_area.left_top.y
    
    -- local x_resolution = area_width  / self.pdata.zoom
    -- local y_resolution = area_height / self.pdata.zoom
    
    local resolution_label = this_frame.add {
      type = 'label',
      -- caption = ('Resolution: %s x %s'):format(x_resolution, y_resolution)
      caption = '<pre-init>'
      }
    gui_elements.resolution_label = resolution_label
      
    -- self:update_resolution()
    
    end
  
  -- Filename + Filesize estimate
  do
    local this_frame = main_anchor.add {
      type = 'frame',
      style = 'inner_frame_in_outer_frame',
      direction = 'vertical',
      }
    this_frame.drag_target = main_anchor
    this_frame.style.width = CONST.GUI.WIDTH
    this_frame.style.height = 16 + 24 * 3
    
    local file_name_header = this_frame.add {
      type = 'label',
      caption = 'Filename [img=info]',
      tooltip = '/script-output/',
      }
    
    local file_name_flow = this_frame.add {
      type = 'table',
      column_count = 2,
      -- column_alignments = {},
      }
    
    local file_name_text_field = file_name_flow.add {
      type = 'textfield',
      -- text = ('%f.1'):format(self.pdata.zoom), 
      -- text = tostring(self.pdata.zoom), --can't enforce format because player may enter arbirary values
      text = '<pre-init>',
      lose_focus_on_confirm = true,
      clear_and_focus_on_right_click = true,
      }
    gui_elements.file_name_text_field = file_name_text_field
    
    file_name_text_field.style.horizontally_stretchable = true
    file_name_text_field.style.horizontally_squashable = true
    file_name_text_field.style.minimal_width = 32
    -- file_name_text_field.style.width = 32
    file_name_text_field.style.height = 24
    set_gui_element_update_handler(file_name_text_field, 'on_player_changed_file_name')
    
    
    local file_extension_drop_down = file_name_flow.add {
      type = 'drop-down',
      items = CONST.ALLOWED_FILE_EXTENSIONS,
      selected_index = self.pdata.gui_state.file_extension_index,
      }
    set_gui_element_update_handler(file_extension_drop_down, 'on_player_changed_file_extension')
    gui_elements.file_extension_drop_down = file_extension_drop_down
      
    file_extension_drop_down.style.width = 64 + 6
    file_extension_drop_down.style.height = 24 
    -- file_extension_drop_down.style.margin = {0,0,0,0}
    file_extension_drop_down.style.padding = {0,4,4,4}
    -- file_extension_drop_down.style.padding = {0,0,0,0}
    
    local file_size_label = this_frame.add {
      type = 'label',
      caption = '<pre-init>',
      }
    gui_elements.file_size_label = file_size_label
    
    -- self:update_file_size()
    end

  -- Advanced options
  do
    -- @future: Proper alignment of the switches seems impossible because
    -- the switch widget is centered *including* the length of both labels.
    local this_frame = main_anchor.add {
      type = 'frame',
      style = 'inner_frame_in_outer_frame',
      direction = 'vertical',
      }
    this_frame.drag_target = main_anchor
    this_frame.style.width = CONST.GUI.WIDTH
    -- this_frame.style.height = 16 + 24 * 5
    
      local this_table = this_frame.add {
        type = 'table',
        column_count = 2,
        style = 'er:screenshot-gui-advanced-option-table',
        }
      -- this_table.style.horizontal_align = 'center'
      -- this_table.style.vertical_align = 'center'
      -- this_table.style.width = CONST.GUI.WIDTH - 24
    local function add_advanced_setting (args)
        
      local this_label = this_table.add {
        type = 'label',
        caption = {'', args.caption, args.tooltip and ' [img=info]'},
        tooltip = args.tooltip,
        }
      -- this_label.style.horizontally_stretchable = true
      this_label.style.width = 100
      
      -- local dummy_flow = this_table.add {
        -- type = 'flow',
        -- }
      -- dummy_flow.style.width = 116
      
      local this_switch = this_table.add {
        type = 'switch',
        switch_state = args.switch_state,
        allow_none_state = false,
        left_label_caption  = args.left_caption,
        right_label_caption = args.right_caption,
        allow_none_state = args.allow_none,
        style = 'er:screenshot-gui-advanced-option-switch',
        }
      
      --attempt to center...
      do
        -- this_switch.style.horizontal_align = 'center'
        -- this_switch.style.horizontally_stretchable = true
        -- this_switch.style.horizontally_squashable = false
        
        
        -- this_switch.style.width = 116
        -- local switch_lable_width = 38
                
        -- this_switch.style.minimal_width = switch_lable_width
        -- this_switch.style.maximal_width = switch_lable_width
        -- this_switch.style.natural_width = switch_lable_width
                
        
        end
      
      -- this_switch.style.width = 64
      set_gui_element_update_handler(this_switch, 'on_player_changed_advanced_options')
      
      return this_switch
      end
    
    gui_elements.show_interface_switch = add_advanced_setting {
      caption = 'Interface',
      tooltip = 'Includes all GUI elements in the screenshot.\n\nMight look weird if the screenshot area is different from your screen resolution.',
      switch_state = self.pdata.gui_state.show_interface_switch_state,
      left_caption = 'hide',
      right_caption = 'show',
      }
      
    gui_elements.show_alt_info_switch = add_advanced_setting {
      caption = 'Alt-Info',
      switch_state = self.pdata.gui_state.show_alt_info_switch_state,
      left_caption = 'hide',
      right_caption = 'show',
      }
      
    gui_elements.enable_anti_aliasing_switch = add_advanced_setting {
      caption = 'Anti-Aliasing',
      tooltip = 'Renders in double resolution and scales down. Can produce blurry images. Not recommended.',
      switch_state = self.pdata.gui_state.enable_anti_aliasing_switch_state,
      left_caption = 'off',
      right_caption = 'on',
      }
      
    gui_elements.daytime_switch = add_advanced_setting {
      caption = 'Time',
      tooltip = 'If not set this will use the current time.',
      switch_state = self.pdata.gui_state.daytime_switch_state,
      left_caption = 'Day',
      right_caption = 'Night',
      allow_none = true,
      }
      
    end
  
  
  -- Dialogue Buttons
  do
    local this_frame = main_anchor.add {
      type = 'frame',
      style = 'inner_frame_in_outer_frame',
      direction = 'horizontal',
      }
    this_frame.drag_target = main_anchor
    this_frame.style.width = CONST.GUI.WIDTH
    
    local close_button = this_frame.add {
      type = 'button',
      style = 'red_back_button',
      caption = 'Exit',
      }
    close_button.style.width = 64
    set_gui_element_update_handler(close_button, 'close')
      
    local confirm_button = this_frame.add {
      type = 'button',
      style = 'confirm_button',
      caption = 'Take Screenshot',
      }
    set_gui_element_update_handler(confirm_button, 'take_screenshot')
        
      
    end
  
  -- self.pdata.is_gui_open = true
  self:load_state()
  end
  
function ScreenshotGui:close()
  -- if not self.pdata.is_gui_open then return end -- better performance
  
  if self.player.clean_cursor() then
    local main_anchor = self:get_main_anchor()
    main_anchor.destroy()
    self.pdata.gui_elements = {}
    end
  
  -- self.pdata.is_gui_open = false
  
  end
  
  
-- -------------------------------------------------------------------------- --
-- Gui State                                                                  --
-- -------------------------------------------------------------------------- --


-- stores state to pdata.gui_state
function ScreenshotGui:save_state()
  error('Not needed, done when each element is clicked?')
  end
  
-- writes state to gui
function ScreenshotGui:load_state()
  local E = self.pdata.gui_elements
  local S = self.pdata.gui_state
  print('load_state pdata', serpent.block(self.pdata))

  E.zoom_slider.slider_value     = zoom_factor_to_zoom_step_index(S.zoom_factor)
  E.zoom_text_field.text = tostring(S.zoom_factor)

  -- local default_file_name = 'screenshot_' .. tick_to_playtime_string(game.tick)
  E.file_name_text_field.text               = S.file_name
  -- E.file_name_text_field.text               = S.file_name or default_file_name
  -- E.file_name_text_field.text               = default_file_name
  E.file_extension_drop_down.selected_index = S.file_extension_index

  E.show_interface_switch      .switch_state = S.show_interface_switch_state
  E.show_alt_info_switch       .switch_state = S.show_alt_info_switch_state
  E.enable_anti_aliasing_switch.switch_state = S.enable_anti_aliasing_switch_state
  E.daytime_switch             .switch_state = S.daytime_switch_state
  
  self:update_resolution()
  self:update_file_size()
  end

-- translates state to internal representation
local SwitchToDaytime = {left = 1, right = 0.5, none = nil}
function ScreenshotGui:translate_state()
  local E = self.pdata.gui_elements
  local S = self.pdata.gui_state

  local state = {
    zoom_factor = S.zoom_factor,
    
    file_name      = E.file_name_text_field.text,
    file_extension = CONST.ALLOWED_FILE_EXTENSIONS[S.file_extension_index],
    
    show_interface       = CONST.SWITCH_STATE [S.show_interface_switch_state      ],
    show_alt_info        = CONST.SWITCH_STATE [S.show_alt_info_switch_state       ],
    enable_anti_aliasing = CONST.SWITCH_STATE [S.enable_anti_aliasing_switch_state],
    daytime              = SwitchToDaytime    [S.daytime_switch_state             ],
    }
  
  return state
  end
  

  
-- -------------------------------------------------------------------------- --
-- Gui Player Input                                                           --
-- -------------------------------------------------------------------------- --

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
    print('gui interacted event', e.element.get_mod())
    if e.element.get_mod() == MOD_NAME then -- api doc says: "not-super-expensive but not free"
      local update_handler_name = get_gui_element_update_handler(e.element)
      if update_handler_name then
        print('calling updater:', update_handler_name, game.tick)
        local sgui = ScreenshotGui.get(e.player_index)
        sgui[update_handler_name](sgui, e.element, e)
        end
      -- local tags = get_gui_element_tags(e.element)
      -- if tags.update_method then
        -- local sgui = ScreenshotGui.get(e.player_index)
        -- sgui[tags.update_method](sgui, e.element, e)
        -- end
      end
    end)
    
function ScreenshotGui:on_player_changed_file_extension(elm, e)
  self.pdata.gui_state.file_extension_index = 
    self.pdata.gui_elements.file_extension_drop_down.selected_index
  self:update_file_size()
  end
  
function ScreenshotGui:on_player_changed_advanced_options(elm, e)
  local E = self.pdata.gui_elements
  local S = self.pdata.gui_state
  S.show_interface_switch_state       = E.show_interface_switch.switch_state      
  S.show_alt_info_switch_state        = E.show_alt_info_switch.switch_state
  S.enable_anti_aliasing_switch_state = E.enable_anti_aliasing_switch.switch_state
  S.daytime_switch_state              = E.daytime_switch.switch_state
  self:update_resolution()
  self:update_file_size()
  end
  
function ScreenshotGui:on_player_changed_file_name(elm, e)
  self.pdata.gui_state.file_name =
    self.pdata.gui_elements.file_name_text_field.text
  end
  
     
function ScreenshotGui:on_player_changed_zoom(elm, e)
  -- @future: detect if slider or text was changed
  
  local zoom_factor
  
  if elm and (elm.type == 'slider') then
    zoom_factor     = zoom_step_index_to_zoom_factor(elm.slider_value)
  else
    zoom_factor     = tonumber(elm.text)
    end

  if not zoom_factor or zoom_factor <= 0 then
    self.pdata.gui_elements.zoom_text_field.style = 'invalid_value_textfield'
    return
  else
    self.pdata.gui_elements.zoom_text_field.style = 'textbox'
    end
  
  local zoom_step_index = zoom_factor_to_zoom_step_index(zoom_factor)
  self.pdata.gui_elements.zoom_text_field .text = tostring(zoom_factor)
  self.pdata.gui_elements.zoom_slider .slider_value = zoom_step_index
  
  -- print(serpent.block(self.pdata))
  self.pdata.gui_state.zoom_factor = zoom_factor
  self.pdata.gui_elements.camera.zoom = zoom_factor
  self.player.zoom = zoom_factor
  self:update_resolution()
  self:update_file_size()
  end
  
function ScreenshotGui:on_player_changed_selection_rectangle()
  self:update_resolution()
  self:update_file_size()
  end
    
-- -------------------------------------------------------------------------- --
-- Gui Update                                                                 --
-- -------------------------------------------------------------------------- --

-- Updaters should *NEVER* call each other

function ScreenshotGui:get_resolution(opts)
  
  local selected_area = self.pdata.selection_rectangle:get_selected_area()
  local area_width  = selected_area.right_bottom.x - selected_area.left_top.x
  local area_height = selected_area.right_bottom.y - selected_area.left_top.y
  
  -- A tile at zoom 1.0 has 32 pixels.
  
  local zoom_factor = self.pdata.gui_state.zoom_factor
  local x_resolution = math.ceil(32 * area_width  * zoom_factor)
  local y_resolution = math.ceil(32 * area_height * zoom_factor)
  
  
  -- Anti aliasing only affects internal render resolution not output resolution.
  
  -- if not (opts and opts.ignore_anti_alias) then
    -- if CONST.SWITCH_STATE[self.pdata.gui_state.enable_anti_aliasing_switch_state] then
      -- x_resolution, y_resolution = x_resolution * 2, y_resolution * 2
      -- end
    -- end

  return x_resolution, y_resolution
  end

  
function ScreenshotGui:update_resolution()

  
  local x_resolution, y_resolution = self:get_resolution()
  
  -- print('area_widht', area_width)
  
  local resolution_label = self.pdata.main_anchor.children[2].children[3]
  
  resolution_label.caption = ('Resolution: %s x %s'):format(x_resolution, y_resolution)
  
  end
  
  
-- function ScreenshotGui:update_camera()
  -- end
  
function ScreenshotGui:update_file_size()
  local ratio = CONST.AVERAGE_COMPRESSION_RATIO
    [CONST.ALLOWED_FILE_EXTENSIONS[self.pdata.gui_state.file_extension_index]]

  local width, height = self:get_resolution()
  local bit_depth = 32
  local bits_per_kilobyte = 8
  local size = ratio * (width * height) * bit_depth / bits_per_kilobyte
    
  local i, suffix = 0, {'KiB', 'MiB', 'GiB'}
  for j = 1, #suffix do
    i = i + 1
    size = size / 1024
    if size < 1024 then break end
    end
    
    
  self.pdata.gui_elements.file_size_label.caption = 
    -- ('Approximate file size: %d MiB'):format(size)
    ('Approximate file size: %d %s'):format(size, suffix[i])
  -- print('filesize updated', game.tick)
  end
  
-- -------------------------------------------------------------------------- --
-- Gui Take Screenshot                                                        --
-- -------------------------------------------------------------------------- --

  
function ScreenshotGui:take_screenshot(elm, e)

  local selected_area = self.pdata.selection_rectangle:get_selected_area()
  local area_width  = selected_area.right_bottom.x - selected_area.left_top.x
  local area_height = selected_area.right_bottom.y - selected_area.left_top.y

  local center = {
    x = selected_area.left_top.x + area_width / 2,
    y = selected_area.left_top.y + area_height / 2
    }
  
  
  local x_resolution, y_resolution = self:get_resolution{ignore_anti_alias = true}
  local resolution = {x_resolution, y_resolution}
  
  -- local filename =
    -- self.pdata.gui_elements.file_name_text_field.text
    -- .. CONST.ALLOWED_FILE_EXTENSIONS[self.pdata.gui_state.file_extension_index]
  
  -- self:load_state()
  local opts = self:translate_state()
  
  
  local filename = opts.file_name .. opts.file_extension
  filename = String.replace(filename, '%playtime%', tick_to_playtime_string(game.tick))
    

    
  local full_args = {
    player = self.player                        ,
    by_player = self.player                     ,
    surface = self.player.surface               ,
                                                
    position = center                           ,
    resolution = resolution                     , -- before anti-alias
                                                
    zoom = opts.zoom_factor                     ,
    path = filename,
                                                
    show_gui = opts.show_interface              ,
    show_entity_info = opts.show_alt_info       ,
    anti_alias = opts.enable_anti_aliasing      ,
    quality = 80                                ,
    allow_in_replay = false                     ,
    daytime = opts.daytime                      ,
    water_tick = nil                            ,
    force_render = true                         ,
    }

  print('take_screnshot options:\n', serpent.block(full_args))
  game.take_screenshot(full_args)
    
  self.player.play_sound{
    path = 'er:camera-click',
    volume_modifier = 0.9,
    }
  end
  
