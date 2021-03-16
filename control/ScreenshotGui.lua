-- (c) eradicator a.k.a lossycrypt, 2017-2020, not seperately licensable

-- -------------------------------------------------------------------------- --
-- Imports                                                                    --
-- -------------------------------------------------------------------------- --

local erlib  = require 'control/erlib-mini'
local String = erlib.String
local Table  = erlib.Table
local Gui    = erlib.Gui

local CONST = require 'control/constants'



-- -------------------------------------------------------------------------- --
-- Local Constants                                                            --
-- -------------------------------------------------------------------------- --

-- local TAG_ELEMENT_NAME = 'er:screenshot-maker-gui-tags'

local UPDATE_HANDLER_TAG_NAME = 'er:screenshot-maker-gui-update-handler'


-- -------------------------------------------------------------------------- --
-- Helper Functions (Zoom)                                                    --
-- -------------------------------------------------------------------------- --




  
-- -------------------------------------------------------------------------- --
-- Helper Functions (Time)                                                    --
-- -------------------------------------------------------------------------- --

local function tick_to_time(tick)
  local seconds = tick / 60
  return {
    h = math.floor(seconds / (60^2)     ),
    m = math.floor(seconds % (60^2) / 60),
    s = math.floor(seconds %  60        ),
    }
  end
  
  
-- regrettably ":" colon isn't valid for windows filenames
local function get_playtime_string()
  local time = tick_to_time(game.ticks_played)
  return (('%3dh_%2dm_%2ds'):format(time.h, time.m, time.s):gsub(' ','0'))
  end  
  
  
  
-- -------------------------------------------------------------------------- --
-- Helper Functions (Gui Tags)                                                --
-- -------------------------------------------------------------------------- --
  
local function set_gui_element_update_handler(elm, name)
  local tag =
    elm[UPDATE_HANDLER_TAG_NAME]
    or elm.add{type='empty-widget',visible=false,name=UPDATE_HANDLER_TAG_NAME}
    -- or elm.add{type='label',visible=false,name=UPDATE_HANDLER_TAG_NAME}
  tag.caption = name
  end
  
local function get_gui_element_update_handler(elm)
  local tag = elm[UPDATE_HANDLER_TAG_NAME]
  if tag then return tag.caption end -- nil if none
  end

-- local function get_gui_element_tags(elm)
--   local tag_flow = elm[TAG_ELEMENT_NAME]
--   if tag_flow then
--     local ok, tags = serpent.load(tag_flow.caption or '')
--     if ok and tags then return tags end
--     end
--   return {}
--   end
-- 
--   
-- local function set_gui_element_tag(elm, key, value)
--   local tags = get_gui_element_tags(elm)
--   tags[key] = value
--   local tag_flow = elm[TAG_ELEMENT_NAME] or elm.add{type='empty-widget',visible=false,name=TAG_ELEMENT_NAME}
--   tag_flow.caption = serpent.line(tags, {compact=true,nocode=true})
--   end



-- -------------------------------------------------------------------------- --
-- Helper Functions (Misc)                                                    --
-- -------------------------------------------------------------------------- --

-- local function apply_style(elm, style)
  -- local s = element.style
  -- for k,v in pairs(style) do s[k] = v end
  -- return elm
  -- end
  
  
-- creates an unwrapped locale string
local function loc(str) return 'er:screenshot-maker.'..str end
  
  
local function get_base_sidebar_height(p)
  -- @future: read game_view_settings, use hardcoded list of menu heights
  return 344
  end
  
  

-- -------------------------------------------------------------------------- --
-- ScreenshotGui (init)                                                       --
-- -------------------------------------------------------------------------- --

local ScreenshotGui = {}
local ScreenshotGui_mt = {__index = ScreenshotGui}


function ScreenshotGui.reclassify (obj)
  return obj and setmetatable(obj, ScreenshotGui_mt)
  end

  
function ScreenshotGui.new(pindex, p)
  return ScreenshotGui.reclassify(
    ScreenshotGui.get_default_gui_state(pindex, p)
    )
  end

  
function ScreenshotGui.get_default_gui_state(pindex, p)
  return {

    pindex = pindex,
    player = p,
  
    selected_area = {left_top = {x = 0, y = 0}, right_bottom = {x = 0, y = 0}},
    resolution    = {x = 0, y = 0},

    -- Raw gui properties for restoring the gui after closing it.
    states = {
      zoom_text_field             = { text = '1'},
      
      file_name_text_field        = { text = 'screenshot_%time%'},
      file_extension_drop_down    = { selected_index = CONST.DEFAULT_FILE_EXTENSION_INDEX},
      file_quality_slider         = { slider_value = 80 },
      
      -- trinary switches
      daytime_override_switch     = { switch_state = 'none' },
      
      -- bool switches (left:false, right:true)
      show_alt_info_switch        = { switch_state = 'right'},
      show_interface_switch       = { switch_state = 'left' },
      include_size_labels_switch  = { switch_state = 'left' },
      enable_anti_aliasing_switch = { switch_state = 'left' },
      },
      
    -- LuaGuiElements that need to be read from / written to.
    elements = {
      main_anchor                 = nil,
      
      zoom_slider                 = nil,
      zoom_text_field             = nil,
      resolution_label            = nil,
      
      file_name_text_field        = nil,
      file_extension_drop_down    = nil,
      file_size_label             = nil,
      
      show_interface_switch       = nil,
      show_alt_info_switch        = nil,
      enable_anti_aliasing_switch = nil,
      daytime_override_switch     = nil,
      },
      
    }
  end


  
-- -------------------------------------------------------------------------- --
-- ScreenshotGui (main_anchor)                                                --
-- -------------------------------------------------------------------------- --

function ScreenshotGui:is_gui_open()
  return (self.elements.main_anchor and self.elements.main_anchor.valid)
      or false
  end

  
function ScreenshotGui:create_main_anchor()
  self.elements.main_anchor = self.player.gui.screen.add{
    type = 'frame',
    style = 'outer_frame',
    name = CONST.GUI.MAIN_ANCHOR_NAME,
    direction = 'vertical',
    }
  return self.elements.main_anchor
  end

  
function ScreenshotGui:destroy_gui()
  local main_anchor = self.player.gui.screen[CONST.GUI.MAIN_ANCHOR_NAME]
  if main_anchor then main_anchor.destroy() end
  self.elements = {}
  end

  
-- -------------------------------------------------------------------------- --
-- ScreenshotGui (custom events)                                              --
-- -------------------------------------------------------------------------- --

do
  local event_handlers = {}
  
  function ScreenshotGui.on_event(event_name, f)
    table.insert(Table.sget(event_handlers, {event_name}, {}), f)
    end
    
  function ScreenshotGui:do_event(event_name)
    for _, f in pairs(event_handlers[event_name] or {}) do
      f {player_index = self.pindex}
      end
    end
    
  end

  
  
-- -------------------------------------------------------------------------- --
-- ScreenshotGui (open / close)                                               --
-- -------------------------------------------------------------------------- --

-- graceful shutdown
function ScreenshotGui:close()
  self:destroy_gui()
  end

do  
  local offsets = {
    show_minimap       = {height = 256, width = 254},
    show_research_info = {height = 36 },
    show_side_menu     = {height = 52 }, -- the button row above the minimap
    }
function ScreenshotGui:get_gui_default_location()
  local gws = self.player.game_view_settings
  local res = self.player.display_resolution
  local scale = self.player.display_scale
  local x_offset = res.width - (scale * offsets.show_minimap.width)
  local y_offset = 0
  for name, offset in pairs(offsets) do
    if gws[name] then
      y_offset = y_offset + offset.height
      end
    end
  return {x_offset, scale * y_offset}
  end
  end
  
  
function ScreenshotGui:open()
  -- clear anchor or create new
  local main_anchor = self.elements.main_anchor
  if main_anchor and main_anchor.valid then
    main_anchor.clear()
  else
    self:destroy_gui()
    main_anchor = self:create_main_anchor()
    end
  -- reset position
  Gui.apply_stylers(main_anchor, CONST.GUI.WIDTH_STYLER)
  main_anchor.location = {
    self.player.display_resolution.width - CONST.GUI.WIDTH,
    get_base_sidebar_height(self.player)
    }
    
  main_anchor.location = self:get_gui_default_location()
    
  --
  -- self:create_title_bar()
  -- self:create_title_bar2()
  self:create_top_frame()
  self:create_zoom_frame()
  self:create_file_frame()
  self:create_options_frame()
  self:create_final_frame()
  --
  self:load_state()
  end

  
  
-- -------------------------------------------------------------------------- --
-- ScreenshotGui (element creator functions)                                  --
-- -------------------------------------------------------------------------- --

--[[ Tooltips style names

  frame
    tooltip_frame
    tooltip_generated_from_description_frame
    tooltip_generated_from_description_blueprint_frame
    multi_tooltip_invisible_frame
    
    tooltip_title_frame_light
    tooltip_panel_background
    
    entity_info_frame
    entity_info_frame_on_cursor
    
    borderless_frame
    naked_frame
    naked_frame_with_no_spacing

  label
    tooltip_label
    tooltip_title_label
    subheader_caption_label
    subheader_right_aligned_label
    tooltip_heading_label
    tooltip_heading_label_category
    electric_usage_label

  line
    tooltip_horizontal_line
    frame_division_fake_horizontal_line
    tooltip_category_line
    blurry_panel_horizontal_line

  ]]


-- A "box" inside the anchor.
function ScreenshotGui:add_empty_frame(style, ...)
  local this = self.elements.main_anchor.add {
    type  = 'frame',
    style = style or CONST.GUI.STYLE.CONTENT_FRAME,
    direction = 'vertical',
    }
  -- this.drag_target = self.elements.main_anchor
  Gui.apply_stylers(this, CONST.GUI.WIDTH_STYLER, ...)
  return this
  end


-- A "box" with a title
function ScreenshotGui:add_frame_with_header(args, ...)
  local header_frame = self:add_empty_frame(CONST.GUI.STYLE.SUB_HEADER_FRAME)
  local header_flow  = header_frame.add{
    type      = 'flow',
    direction = 'horizontal',
    }
  local header_label = header_flow.add{
    type    = 'label',
    caption = args.header,
    tooltip = args.tooltip,
    style   = CONST.GUI.STYLE.SUB_HEADER_LABEL,
    }
  local content_frame = self:add_empty_frame(CONST.GUI.STYLE.CONTENT_FRAME, ...)
  return content_frame, header_frame, header_label, header_flow
  end


function ScreenshotGui:add_frame_with_draggable_header(args, ...)
  local content_frame, header_frame, header_label, header_flow
    = self:add_frame_with_header(args, ...)
  local drag_handle = header_flow.add{
    type = 'empty-widget',
    style = CONST.GUI.STYLE.DRAG_HANDLER,
    }
  header_flow.drag_target = self.elements.main_anchor
  header_label .ignored_by_interaction = (not args.tooltip)
  drag_handle  .ignored_by_interaction = true
  Gui.apply_stylers(drag_handle, {
    horizontally_stretchable = true,
    vertically_stretchable   = true,
    })
  return content_frame, header_frame
  end

  
-- Generic LuaGuiElement creation and storage
function ScreenshotGui:add_element(opts, args, ...)
  local this = opts.parent.add(args)
  if opts.name then
    self.elements[opts.name] = this
    end
  if opts.update then
    set_gui_element_update_handler(this, opts.update)
    end
  Gui.apply_stylers(this, ...)
  return this
  end

function ScreenshotGui:add_aligned_switch(opts, args, ...)
  if not opts.width then error('aligned switch needs width') end
  --
  local switch_table = opts.parent.add{
    name  = args.name, -- element name
    type  = 'table',
    column_count = 3,
    style = 'er:screenshot-gui-aligned-switch-table',
    -- type  = 'flow',
    -- direction = 'horizontal',
    }
  switch_table.style.width = opts.width
  --
  self:add_element({
    parent = switch_table,
    update = 'on_player_clicked_aligned_switch',
    },{
    type    = 'label',
    style   = 'er:screenshot-gui-aligned-switch-inactive-label',
    caption = args.left_label_caption,
    },{
    -- horizontal_align = 'right', -- for flow
    -- width = (opts.width - 32) / 2, -- 32 == switch button width
    })
  self:add_element({
    name   = opts.name, -- storage name
    parent = switch_table,
    update = 'on_player_clicked_aligned_switch',
    },{
    type                = 'switch',
    name                = 'aligned-switch',
    switch_state        = CONST.GUI.DUMMY_SWITCH_STATE,
    allow_none_state    = args.allow_none_state,
    })
  self:add_element({
    parent = switch_table,
    update = 'on_player_clicked_aligned_switch',
    },{
    type    = 'label',
    style   = 'er:screenshot-gui-aligned-switch-inactive-label',
    caption = args.right_label_caption,
    },{
    -- horizontal_align = 'left', -- for flow
    -- width = (opts.width - 32) / 2,
    })
  if opts.update then
    set_gui_element_update_handler(switch_table, opts.update)
    end
  return switch_table
  end

  
-- -------------------------------------------------------------------------- --
-- ScreenshotGui (create elements)                                            --
-- -------------------------------------------------------------------------- --
  
-- Title bar + drag handle + help button + close button
function ScreenshotGui:create_top_frame()

  local this_frame, this_header = self:add_frame_with_draggable_header(
    -- {height = 28}
    -- header = {loc'string-with-tooltip', {loc'gui-title'}},
    {header = {loc'gui-title'},}
    )
  this_header.style = CONST.GUI.STYLE.TOP_HEADER_FRAME

  local this_table = this_frame.add{
    type = 'table',
    column_count = 2,
    style = 'er:screenshot-gui-status-table',
    }

  self:add_element({
    parent = this_table,
    },{
    type = 'label',
    caption = {loc'string-with-tooltip', {loc'status-resolution-label'}},
    tooltip = {
      loc'status-resolution-tooltip',
      {'',
        {loc'input-tooltip-template',
          {loc'input-left-click-key'},
          {loc'input-select-description'},
          },
        {loc'input-tooltip-template',
          {loc'input-left-click-key'},
          {loc'input-resize-description'},
          },
        {loc'input-tooltip-template',
          {loc'input-left-click-key'},
          {loc'input-move-description'},
          },
        {loc'input-tooltip-template',
          {loc'input-right-click-key'},
          {loc'input-delete-description'},
          },
        {loc'input-tooltip-template',
          {loc'input-rotate-key'},
          {loc'input-rotate-description',{loc'input-left-click-key'}},
          },
        }
      }
    
    })
    
  self:add_element({
    name = 'resolution_label',
    parent = this_table,
    },{
    type = 'label',
    caption = '<pre-init>',
    })

  self:add_element({
    parent = this_table,
    },{
    type = 'label',
    caption = {loc'string-with-tooltip', {loc'status-file-size-label'}},
    tooltip = {loc'status-file-size-tooltip'},
    })
    
  self:add_element({
    name = 'file_size_label',
    parent = this_table,
    },{
    type = 'label',
    caption = '<pre-init>',
    })

  end
  
-- Zoom slider + Resolution label
function ScreenshotGui:create_zoom_frame()

  local this_frame = self:add_frame_with_draggable_header(
    {
    header = {loc'string-with-tooltip', {loc'zoom-label'}},
    tooltip = {loc'zoom-tooltip'},
    }
    )

  local zoom_flow = this_frame.add {
    type = 'table',
    column_count = 2,
    }

  --[[
  local this_frame = self:add_empty_frame()
  local zoom_label = zoom_flow.add {
    type = 'label',
    caption = {loc'string-with-tooltip', {loc'zoom-label'}},
    tooltip = {loc'zoom-tooltip'},
    }
  zoom_label.style.height = 16
  --]]

  self:add_element({
    name   = 'zoom_slider',
    parent =  zoom_flow,
    update = 'on_player_changed_zoom',
    },{
    type = 'slider',
    minimum_value = 1,
    maximum_value = #CONST.GUI.ZOOM_STEPS,
    value = 1,
    value_step = 1,
    discrete_slider = true,
    discrete_values = true,
    style = 'notched_slider',
    },{
    horizontally_stretchable = true,
    horizontally_squashable  = true,
    minimal_width            = 24  ,
    })

  self:add_element({
    name   = 'zoom_text_field',
    parent =  zoom_flow,
    update = 'on_player_changed_zoom',
    },{
    type = 'textfield',
    text = '0',
    numeric = true,
    allow_decimal = true,
    allow_negative = false,
    lose_focus_on_confirm = true,
    clear_and_focus_on_right_click = true,
    },{
    width  = 32 + 24,
    height = 24,
    horizontal_align = 'center',
    })
    

    
  end

  
-- Filename + Filesize estimate
function ScreenshotGui:create_file_frame()

  local this_frame = self:add_frame_with_draggable_header(
    {
      header  = {loc'string-with-tooltip', {loc'file-header'}},
      tooltip = {
        '',
        {loc'file-location-explanation'},
        '\n', '\n',
        {loc'file-name-patterns-explanation',
          {'',
            '\n',
            {loc'file-name-pattern-template',
              '%time%',
              {loc'file-name-pattern-time'},
              },
            '\n',
            {loc'file-name-pattern-template',
              '%tick%',
              {loc'file-name-pattern-tick'},
              },
            },
          },
        },
      }
    -- ,{height = 16 + 24 * 3}
    )

  local file_name_flow = this_frame.add {
    type = 'table',
    column_count = 2,
    -- column_alignments = {},
    }
    
  self:add_element({
    name   = 'file_name_text_field',
    parent =  file_name_flow,
    update = 'on_player_changed_file_name',
    },{
    type = 'textfield',
    text = '<pre-init>',
    lose_focus_on_confirm = true,
    clear_and_focus_on_right_click = true,
    },{
    horizontally_stretchable = true,
    horizontally_squashable = true,
    minimal_width = 32,
    height = 24,
    })

  self:add_element({
    name = 'file_extension_drop_down',
    parent = file_name_flow,
    update = 'on_player_changed_file_extension',
    },{
    type = 'drop-down',
    items = CONST.ALLOWED_FILE_EXTENSIONS,
    selected_index = nil,
    },{
    width = 64 + 6,
    height = 24,
    padding = {0,4,4,4},
    -- margin = {0,0,0,0},
    -- padding = {0,0,0,0},
    })
    
    
  local file_quality_flow = self:add_element({
    name = 'file_quality_flow',
    parent = this_frame,
    },{
    type = 'flow',
    },{
    height = 24,
    vertical_align = 'bottom', -- doesn't seem to have any effect
    })
      
  file_quality_flow.add {
    type = 'label',
    caption = {loc'file-quality-label'},
    tooltip = {loc'file-quality-tooltip'},
    }
    
  self:add_element({
    name = 'file_quality_slider',
    parent = file_quality_flow,
    update = 'on_player_changed_file_quality',
    },{
    type = 'slider',
    minimum_value = 50, -- looks ridiculously bad below this.
    maximum_value = 100,
    value = 100, -- dummy
    value_step = 5,
    discrete_slider = true,
    discrete_values = true,
    style = 'notched_slider',
    },{
    horizontally_stretchable = true,
    horizontally_squashable  = true,
    minimal_width            = 24  ,
    })
    
  end
  
  
-- Advanced options
function ScreenshotGui:create_options_frame()

  local this_frame = self:add_frame_with_draggable_header(
    {
      -- header  = {loc'string-with-tooltip', {loc'options-header'}},
      header  = {loc'options-header'},
      }
    )
    
  local this_table = this_frame.add {
    type = 'table',
    column_count = 2,
    style = 'er:screenshot-gui-advanced-option-table',
    }

  local function add_advanced_setting (opts)
    if opts.tooltip then
      opts.caption = {loc'string-with-tooltip', opts.caption}
      end
    local this_label = self:add_element({
      parent = this_table,
      },{
      type    = 'label',
      caption = opts.caption,
      tooltip = opts.tooltip,
      },{
      -- width = 100,
      width = 80,
      })

    -- V3: Custom aligned-switch table
    self:add_aligned_switch({
      name   = opts.name,
      parent = this_table,
      update = 'on_player_changed_advanced_options',
      width  = 140,
      },{
      -- type                = 'switch',
      -- type                = 'aligned-switch',
      switch_state        = CONST.GUI.DUMMY_SWITCH_STATE,
      left_label_caption  = opts.off_caption,
      right_label_caption = opts.on_caption,
      allow_none_state    = opts.allow_none,
      -- style = 'er:screenshot-gui-advanced-option-switch',
      })
    
    -- -- V1: Use switches built-in labels
    -- self:add_element({
    --   name   = opts.name,
    --   parent = this_table,
    --   update = 'on_player_changed_advanced_options',
    --   },{
    --   type                = 'switch',
    --   switch_state        = CONST.GUI.DUMMY_SWITCH_STATE,
    --   left_label_caption  = opts.off_caption,
    --   right_label_caption = opts.on_caption,
    --   allow_none_state    = opts.allow_none,
    --   style = 'er:screenshot-gui-advanced-option-switch',
    --   })
    
    -- -- V2: Manual labels
    -- local switch_table = this_table.add{
    --   type  = 'table',
    --   style = 'er:screenshot-gui-aligned-switch-table',
    --   column_count = 3,
    --   
    --   }
    -- -- switch_table.style.width = 140 --tmp
    -- print('new switch')
    -- print(switch_table.add {
    --   name = 'left_label', type = 'label', caption = opts.off_caption,
    --   style = 'er:screenshot-gui-aligned-switch-inactive-label',
    --   }.index)
    -- local this_switch = self:add_element({
    --   name   = opts.name,
    --   parent = switch_table,
    --   update = 'on_player_changed_advanced_options',
    --   },{
    --   type                = 'switch',
    --   switch_state        = CONST.GUI.DUMMY_SWITCH_STATE,
    --   allow_none_state    = opts.allow_none,
    --   },{
    --   -- width = 40,
    --   })
    -- print(this_switch.index)
    -- print(this_switch.children[1].index)
    -- print(switch_table.add {
    --   name = 'right_label', type = 'label', caption = opts.on_caption,
    --   style = 'er:screenshot-gui-aligned-switch-inactive-label',
    --   }.index)
    end
    
  add_advanced_setting {
    name        = 'daytime_override_switch',
    caption     = {loc'option-daytime-override-label'  },
    tooltip     = {loc'option-daytime-override-tooltip'},
    off_caption = {loc'option-switch-night'},
    on_caption  = {loc'option-switch-day' },
    allow_none  = true,
    }
    
  add_advanced_setting {
    name        = 'show_alt_info_switch',
    caption     = {loc'option-show-alt-info-label'  },
    tooltip     = {loc'option-show-alt-info-tooltip'},
    off_caption = {loc'option-switch-hide'},
    on_caption  = {loc'option-switch-show'},
    }
    
  add_advanced_setting {
    name        = 'show_interface_switch',
    caption     = {loc'option-show-interface-label'  },
    tooltip     = {loc'option-show-interface-tooltip'},
    off_caption = {loc'option-switch-hide'},
    on_caption  = {loc'option-switch-show'},
    }
    
  add_advanced_setting {
    name        = 'include_size_labels_switch',
    caption     = {loc'option-include-size-labels-label'  },
    tooltip     = {loc'option-include-size-labels-tooltip'},
    off_caption = {loc'option-switch-exclude'},
    on_caption  = {loc'option-switch-include'},
    }
    
  if CONST.GUI.SHOW_ANTI_ALIASING_OPTION then
    add_advanced_setting { -- deprecated
      name        = 'enable_anti_aliasing_switch',
      caption     = {loc'option-enable-anti-aliasing-label'  },
      tooltip     = {loc'option-enable-anti-aliasing-tooltip'},
      off_caption = {loc'option-switch-off'},
      on_caption  = {loc'option-switch-on' },
      }
    end
  end
  

-- Dialogue Buttons
function ScreenshotGui:create_final_frame()

  local this_frame = self:add_empty_frame(
    CONST.GUI.STYLE.FINAL_FRAME
    -- , {height = 40}
    )

  local this_flow = this_frame.add {
    type = 'flow',
    direction = 'horizontal',
    }
    
  self:add_element({
    parent  =  this_flow,
    update  = 'on_player_clicked_exit_button',
    },{
    type    = 'button',
    style   = 'red_back_button',
    caption = {loc'dialogue-button-exit'},
    },{
    -- width = 16*5,
    minimal_width = 16*3,
    horizontally_stretchable = true,
    horizontally_squashable  = true,
    left_padding  = 2,
    right_padding = 0,
    })
    
  self:add_element({
    parent  =  this_flow,
    update  = 'take_screenshot',
    },{
    type    = 'button',
    style   = 'confirm_button',
    caption = {loc'dialogue-button-take-screenshot'},
    },{
    minimal_width = 16*3,
    horizontally_stretchable = true,
    horizontally_squashable  = true,
    left_padding  = 0,
    right_padding = 2,
    })

  end
  

  
-- -------------------------------------------------------------------------- --
-- ScreenshotGui (state save + load)                                          --
-- -------------------------------------------------------------------------- --

-- @tparam string name The name of a storable element.
-- @tparam array keys The properties that should be stored.
function ScreenshotGui:store_state(name, keys)
  for _, k in pairs(keys) do
    -- some elements have conditional existance
    if self.elements[name] then
      self.states[name][k] = self.elements[name][k]
      end
    end
  end

  
-- Loads the *entire* gui state.
function ScreenshotGui:load_state()
  for name, element in pairs(self.elements) do
    for k, v in pairs(self.states[name] or {}) do
      element[k] = v
      end
    end
  self:update_zoom() -- zoom_factor -> zoom_slider
  self:update_resolution()
  self:update_file_size()
  self:update_aligned_switch_labels()
  -- print('state loaded')
  end



-- -------------------------------------------------------------------------- --
-- ScreenshotGui (events)                                                     --
-- -------------------------------------------------------------------------- --

-- @future: Keep a list of "intering" (clickable)
-- element indexes and ignore everything else.
function ScreenshotGui:is_member(element)
  local main_anchor = self.elements.main_anchor
  if main_anchor and main_anchor.valid then
    repeat
      if element == main_anchor then return true end
      element = element.parent
      until element == nil
    end
  return false
  end


function ScreenshotGui:on_player_clicked_something(e)
  local update_handler_name = get_gui_element_update_handler(e.element)
  if update_handler_name then
    -- print('calling updater:', update_handler_name, game.tick)
    self[update_handler_name](self, e.element, e)
    end
  end

function ScreenshotGui:on_player_clicked_aligned_switch(elm, e)
  -- triggers for clicks on any of the three components!
  local switch_table = e.element.parent
  if switch_table == e.element then return end
  local left_label  = switch_table.children[1]
  local switch      = switch_table.children[2]
  local right_label = switch_table.children[3]
  --
  local function switch_if_changed(side)
    if switch.switch_state ~= side then
      -- "gui_click" is not the correct sound for switches, but playing
      -- custom sounds does not currently work at high zoom-out @factorio 1.1
      self.player.play_sound {
        path = 'utility/gui_click',
        override_sound_type = 'gui-effect', -- 1.1.7
        }
      -- self.player.play_sound {path = 'er:gui-switch-click'}
      switch.switch_state = side
      end
    end
  if e.element == left_label then
    switch_if_changed 'left'
  elseif e.element == right_label then
    switch_if_changed 'right'
  else
    -- switch.switch_state = 'none'
    end
  --
  self:update_aligned_switch_labels()
  --
  local update_handler_name = get_gui_element_update_handler(switch_table)
  if update_handler_name then
    e.element = switch_table
    self:on_player_clicked_something(e)
    end
  end
    
function ScreenshotGui:on_player_changed_file_extension()
  self:store_state('file_extension_drop_down', {'selected_index'})
  self:update_file_size()
  end

  
function ScreenshotGui:on_player_changed_file_quality()
  self:store_state('file_quality_slider', {'slider_value'})
  self:update_file_size()
  end

  
function ScreenshotGui:on_player_changed_advanced_options()
  self:store_state('daytime_override_switch'    , {'switch_state'})
  self:store_state('show_alt_info_switch'       , {'switch_state'})
  self:store_state('show_interface_switch'      , {'switch_state'})
  self:store_state('include_size_labels_switch' , {'switch_state'})
  self:store_state('enable_anti_aliasing_switch', {'switch_state'})
  self:update_resolution()
  self:update_file_size()  
  end


function ScreenshotGui:on_player_changed_file_name()
  self:store_state('file_name_text_field', {'text'})
  end


function ScreenshotGui:on_player_clicked_exit_button()
  self:do_event('on_player_clicked_exit_button')
  end


function ScreenshotGui:on_player_changed_zoom(elm, e)

  -- internal use converters
  -- @future: shorten(?) and integrate

  -- local function zoom_step_index_to_zoom_factor (zoom_step_index)
    -- return tostring(CONST.GUI.ZOOM_STEPS[tonumber(zoom_step_index)])
    -- end
  
  -- detect slider or text
  if elm and (elm.type == 'slider') then
    self.elements.zoom_text_field.text
      = tostring(CONST.GUI.ZOOM_STEPS[elm.slider_value])
      -- = zoom_step_index_to_zoom_factor(elm.slider_value)
    end
  
  -- store even if invalid
  self:store_state('zoom_text_field', {'text'})
  
  if self:update_zoom() then
    self:update_resolution()
    self:update_file_size()
    end
  
  end
  
  
-- -------------------------------------------------------------------------- --
-- ScreenshotGui (Api)                                                        --
-- -------------------------------------------------------------------------- --

function ScreenshotGui:on_player_changed_selected_area(selected_area)
  self.selected_area = selected_area
  self:update_resolution()
  self:update_file_size()
  end

  

-- -------------------------------------------------------------------------- --
-- ScreenshotGui (update labels)                                              --
-- [Updaters read self.state and apply it to self.elements]                   --
-- -------------------------------------------------------------------------- --

function ScreenshotGui:restyle_zoom_text_field()
  -- styler hotfix (needs re-application after "style" change)
  Gui.apply_stylers(self.elements.zoom_text_field, {
    width  = 32 + 24,
    height = 24,
    horizontal_align = 'center',
    })
  end


-- Verify user input + apply zoom
function ScreenshotGui:update_zoom()
  local zoom_factor = tonumber(self.states.zoom_text_field.text)
  -- invalid
  if not zoom_factor or zoom_factor <= 0 then
    self.elements.zoom_text_field .style   = 'invalid_value_textfield'
    self.elements.resolution_label.caption = {loc'zoom-invalid-label'}
    self.elements.file_size_label .caption = '0 KiB'
    self:restyle_zoom_text_field()
    return false
    end
  -- valid
  self.elements.zoom_text_field.style = 'textbox'
  self.player.zoom = zoom_factor
  self:restyle_zoom_text_field()
  -- update slider
  local function zoom_factor_to_zoom_step_index()
    -- @future: reverse scan order to prevent accidential very-far zoomout
    local k = 1
    for i = 1, #CONST.GUI.ZOOM_STEPS do
      if CONST.GUI.ZOOM_STEPS[i] <= zoom_factor then k = i end
      end
    return k
    end
  self.elements.zoom_slider.slider_value
    = zoom_factor_to_zoom_step_index()
  return true
  end
  

function ScreenshotGui:update_resolution()
  --
  local selected_area = self.selected_area
  local area_width  = selected_area.right_bottom.x - selected_area.left_top.x
  local area_height = selected_area.right_bottom.y - selected_area.left_top.y
  -- A tile at zoom 1.0 has 32 pixels.
  local zoom_factor = tonumber(self.states.zoom_text_field.text)
  if not (zoom_factor and zoom_factor > 0) then return end
  self.resolution.x = math.ceil(32 * area_width  * zoom_factor)
  self.resolution.y = math.ceil(32 * area_height * zoom_factor)
  --
  self.elements.resolution_label.caption
    = ('%s x %s'):format(self.resolution.x, self.resolution.y)
  --
  local long_side = math.max(self.resolution.x, self.resolution.y)
  if math.min(self.resolution.x, self.resolution.y) == 0 then
    self.elements.resolution_label.style = 'label'
  elseif long_side < 4096 then
    self.elements.resolution_label.style = 'er:screenshot-gui-bold-green-label'
  elseif long_side < 16384 then
    self.elements.resolution_label.style = 'er:screenshot-gui-bold-yellow-label'
  else
    self.elements.resolution_label.style = 'er:screenshot-gui-bold-red-label'
    end
  --
  return self.resolution
  end


function ScreenshotGui:update_file_size()
  local file_extension = CONST.ALLOWED_FILE_EXTENSIONS[self.states.file_extension_drop_down.selected_index]
  local ratio = CONST.AVERAGE_COMPRESSION_RATIO[file_extension]

  if CONST.FORMATS_WITH_QUALITY[file_extension] then
    -- This is bullshit. Under/Over-estimates by factor 2 for high/low values.
    -- There's about a factor 10 size difference between Q50% and Q100%.
    local quality = self.states.file_quality_slider.slider_value
    ratio = ratio * (quality / 100)
    end
  
  local width, height = self.resolution.x, self.resolution.y
  local bit_depth = 32
  local bits_per_byte = 8
  local size = ratio * (width * height) * bit_depth / bits_per_byte
    
  local i, suffix = 0, {'KiB', 'MiB', 'GiB'}
  for j = 1, #suffix do
    i = i + 1
    size = size / 1024
    if size < 1024 then break end
    end
    
  self.elements.file_size_label.caption
    = ('%d %s'):format(math.ceil(size), suffix[i])
    
  -- file quality slider
  self.elements.file_quality_flow.visible
    = not not CONST.FORMATS_WITH_QUALITY[file_extension]
  self.elements.file_quality_slider.tooltip
    = ('%s%%'):format(self.states.file_quality_slider.slider_value)
  end


function ScreenshotGui:update_aligned_switch_labels()
  local _styles = {
    [true ] = 'er:screenshot-gui-aligned-switch-active-label'  ,
    [false] = 'er:screenshot-gui-aligned-switch-inactive-label',
    }
  for _, elm in pairs(self.elements) do
    if elm.name == 'aligned-switch' then
      -- 1,2,3 -> left-label, switch, right-label
      local switch_table = elm.parent
      local switch_state = switch_table.children[2].switch_state
      switch_table.children[1].style = _styles['left'  == switch_state]
      switch_table.children[3].style = _styles['right' == switch_state]
      end
    end
  end

-- -------------------------------------------------------------------------- --
-- ScreenshotGui (take_screenshot)                                            --
-- -------------------------------------------------------------------------- --

  
function ScreenshotGui:take_screenshot(elm, e)
  -- Paranoia: Ensure player sees what they got!
  self:load_state()
  local args = {}
  
  -- player + surface
  args. player    = self.player
  args. by_player = self.player
  args. surface   = self.selected_surface or self.player.surface
  
  -- misc
  args. quality         = self.states.file_quality_slider.slider_value
  args. water_tick      = nil
  args. force_render    = true
  args. allow_in_replay = false
  
  -- file
  local file_folder    = '' -- @future
  local file_name      = self.states.file_name_text_field.text
  local file_extension = CONST.ALLOWED_FILE_EXTENSIONS[
    self.states.file_extension_drop_down.selected_index
    ]
  local file_path = file_folder .. file_name .. file_extension
  -- dynamic patterns
  file_path  = String.replace(file_path, '%time%', get_playtime_string(game.tick))
  file_path  = String.replace(file_path, '%tick%'    , game.tick)
  -- path cleanup
  args. path = file_path
    :gsub('\\','/') -- convert backward to forward slash
    :gsub('/+','/') -- remove double slashes
    :gsub('^/','' ) -- remove leading slash
  
  -- options
  local function switch_to_bool(name)
    return CONST.GUI.ON_OFF_SWITCH_STATE[self.states[name].switch_state]
    end
  local function switch_to_daytime(name)
    return CONST.GUI.DAYTIME_SWITCH_STATE[self.states[name].switch_state]
    end
  args. show_gui          = switch_to_bool('show_interface_switch')
  args. show_entity_info  = switch_to_bool('show_alt_info_switch')
  args. anti_alias        = switch_to_bool('enable_anti_aliasing_switch')
  args. daytime           = switch_to_daytime('daytime_override_switch')
  
  -- zoom
  args. zoom = tonumber(self.states.zoom_text_field.text)
  if not (args.zoom and args.zoom > 0) then return end
  
  -- position
  local selected_area = self.selected_area
  local area_width  = selected_area.right_bottom.x - selected_area.left_top.x
  local area_height = selected_area.right_bottom.y - selected_area.left_top.y
  args. position = {
    x = selected_area.left_top.x + area_width  / 2,
    y = selected_area.left_top.y + area_height / 2,
    }
  
  -- resolution
  if math.min(self.resolution.x, self.resolution.y) <= 0
  or math.max(self.resolution.x, self.resolution.y) >  16384
  then  
    -- Invalid resolution -> Use Full-Screen Mode
    local res = self.player.display_resolution
    args .resolution = {x = res.width, y = res.height}
    args .position   = self.player.position
  else
    args. resolution = self.resolution
    -- include labels?
    if CONST.GUI.ON_OFF_SWITCH_STATE[
      self.states.include_size_labels_switch.switch_state]
      then
      args.resolution.x = args.resolution.x + (64 * args.zoom)
      args.resolution.y = args.resolution.y + (64 * args.zoom)
      end
    end
    
  -- take screenshot
  if self.player.name == 'eradicator' then
    print('screenshot gui states:', serpent.block(self))
    print('take_screenshot args: ', serpent.block(args))
    end
  game.take_screenshot(args)    
  
  -- notify player
  self.player.play_sound{
    path = 'er:camera-click',
    volume_modifier = 0.9,
    override_sound_type = 'gui-effect', -- 1.1.7
    }
  end
  
  
-- -------------------------------------------------------------------------- --
-- X                                                                          --
-- -------------------------------------------------------------------------- --

return ScreenshotGui