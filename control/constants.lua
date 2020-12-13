
local CONST = {

  -- NAMES

  MOD_NAME  = 'eradicators-screenshot-maker',
  MOD_ROOT  = '__eradicators-screenshot-maker__/',
  ITEM_NAME = 'er:screenshot-camera',
  
  EVENT = {
    RIGHT_CLICK  = 'er:screenshot-camera:right-click', -- linked input
    ROTATE_RIGHT = 'er:screenshot-camera:rotate-right',
    ROTATE_LEFT  = 'er:screenshot-camera:rotate-left',
    },
  
  -- MISC

  SAVEDATA_PATH = {'plugin_manager', 'plugins', 'screenshot-maker'},

  -- SELECTION RECTANGLE
  
  SELECTION_RECTANGLE = {
    COLOR = {r=0.8, g=0.8, b=0.8, a=0.8},
    },
  
  -- GUI
  
  GUI = {
    MAIN_ANCHOR_NAME = 'er:screenshot-camera:main-anchor',
    
    WIDTH = 256 - 2,
    WIDTH_STYLER = {width = 256 - 2},
    
    -- It does no good, but it's techically there...
    -- SHOW_ANTI_ALIASING_OPTION = true,
    SHOW_ANTI_ALIASING_OPTION = false,
    
    -- Dummy states are used during gui element creation before
    -- loading the actual value from Savedata.
    DUMMY_SWITCH_STATE = 'left',
    
    ZOOM_STEPS = {
      -- 2 is twice zoomed-in, 0.25 is four times zoomed-out.
      -- natural mouse-wheel zoom order
      1/16, 1/8, 1/4, 1/2, 1, 2, 4
      },
      
    ON_OFF_SWITCH_STATE = {
      ['left' ] = false, [false] = 'left' ,
      ['right'] = true , [true ] = 'right',
      },
      
    DAYTIME_SWITCH_STATE = {
      ['left' ] = 0.5,
      ['right'] = 1.0,
      ['none' ] = nil,
      },
      
    STYLE = {
      TOP_HEADER_FRAME = 'tooltip_title_frame_light',
      
      SUB_HEADER_FRAME = 'tooltip_title_frame_light',
      -- SUB_HEADER_FRAME = 'tooltip_frame',
      
      -- SUB_HEADER_LABEL = 'subheader_caption_label',
      SUB_HEADER_LABEL = 'tooltip_heading_label',
      
      -- CONTENT_FRAME    = 'inner_frame_in_outer_frame',
      -- CONTENT_FRAME    = 'tooltip_panel_background',
      -- CONTENT_FRAME    = 'tooltip_title_frame_light',
      -- CONTENT_FRAME    = 'entity_info_frame',
      CONTENT_FRAME    = 'tooltip_frame',
      
      -- DRAG_HANDLER     = 'draggable_space_header',
      -- DRAG_HANDLER     = 'draggable_space',
      DRAG_HANDLER     = nil,
      
      -- FINAL_FRAME      = 'tooltip_title_frame_light',
      FINAL_FRAME      = 'tooltip_frame',
      }
      
      
    },

  ALLOWED_FILE_EXTENSIONS = {
    -- drop-down menu order
    '.png', '.bmp', '.jpg', '.gif', '.tif',
    },
    
  DEFAULT_FILE_EXTENSION_INDEX = 1,
   
  FORMATS_WITH_QUALITY = {
    ['.jpg'] = true,
    },
   
  AVERAGE_COMPRESSION_RATIO = {
    -- Derived from minimal in-game testing.
    ['.bmp'] = 1   ,
    ['.png'] = 0.5 ,
    ['.jpg'] = 0.1 ,
    ['.gif'] = 0.15,
    ['.tif'] = 0.7 ,
    },
   
  }



return CONST