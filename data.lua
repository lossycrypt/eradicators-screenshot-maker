--TODO: make invisible cursor box (copy "make_cursor_box" function to make util sprites).

local MOD_ROOT = '__eradicators-screenshot-maker__/'

local asset = function(path) return (MOD_ROOT..path):gsub('/+','/') end

data:extend{
  { type = 'custom-input',
    name = 'er:screenshot-tool',
    -- key_sequence = 'PRINTSCREEN',
    key_sequence = 'F12',
    order = 'a',
    },
  { type = 'custom-input',
    name = 'er:screenshot-hotkey',
    -- key_sequence = 'CONTROL + PRINTSCREEN',
    key_sequence = 'CONTROL + F12',
    order = 'b',
    },
  }

for _,control in pairs{
  -- 'rotate',
  -- 'build','mine',
  -- 'open-gui',
  -- 'move-down','move-left','move-right','move-up',
  'clean-cursor',
  } do
  local name = 'er:controls:'..control
  if not (data.raw['custom-input'] and data.raw['custom-input'][name]) then
    data:extend{{
      type                = 'custom-input' ,
      name                = name           ,
      key_sequence        = ''             , --nil is invalid
      linked_game_control = control        }}
    end
  end


  
data:extend{{
  -- This allows loading the selection-tool type item when mods are removed
  type = 'selection-tool',
  name = 'er:screenshot-tool',
  -- localised_name = {'item-name.blueprint'},
  icon = asset '/camera.png',
  icon_size = 96,
  -- flags = {'goes-to-quickbar', 'hidden'}, --0.16
  flags = {'hidden','only-in-cursor'}, --0.17
  -- subgroup = 'tool',
  -- order = 'c[automated-construction]-a[blueprint]',
  stack_size = 1,
  stackable = false,
  selection_color = { r = 0, g = 0, b = 0 },
  alt_selection_color = { r = 1, g = 1, b = 1 , a = 0}, --alt mode invisible == disabled
  -- Valid values are: blueprint, deconstruct, cancel-deconstruct, items, trees, buildable-type, tiles, items-to-place, any-entity, any-tile, matches-force
  -- selection_mode = {'blueprint'},
  -- alt_selection_mode = {'blueprint'},
  selection_mode = {'any-entity'},
  alt_selection_mode = {'any-entity'},
  selection_cursor_box_type = 'copy',
  alt_selection_cursor_box_type = 'copy',
  show_in_library = false
  }}
  
data:extend{{
  type = "sound",
  name = 'er:camera-click',
  variations = {
    {filename = asset '/camera-click.ogg'},
    },
  volume = 1
	}}