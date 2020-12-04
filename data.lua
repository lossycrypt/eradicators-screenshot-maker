--TODO: make invisible cursor box (copy "make_cursor_box" function to make util sprites).



local MOD_ROOT = '__eradicators-screenshot-maker__/'
local asset = function(path) return (MOD_ROOT..path):gsub('/+','/') end

local ITEM_NAME = 'er:screenshot-camera'

local ICONS_96 = {{
  icon     = asset 'camera.png',
  icon_size = 96,
  }}
  
local SPRITE_96 = {
  filename = asset 'camera.png',
  size = 96,
  }

-- -------------------------------------------------------------------------- --
-- Hotkey                                                                     --
-- -------------------------------------------------------------------------- --

data:extend{{ type = 'custom-input',
  name = ITEM_NAME,
  -- key_sequence = 'PRINTSCREEN',
  key_sequence = 'F12',
  order = 'a',
  }}

-- -------------------------------------------------------------------------- --
-- Shortcut                                                                   --
-- -------------------------------------------------------------------------- --

data:extend{{
  type = 'shortcut',
  name = ITEM_NAME,
  -- action = 'create-blueprint-item',
  action = 'lua',
  -- item_to_create = ITEM_NAME,
  associated_control_input = ITEM_NAME,
  icon = SPRITE_96,
  }}

-- -------------------------------------------------------------------------- --
-- Sound                                                                      --
-- -------------------------------------------------------------------------- --

data:extend{{
  type = "sound",
  name = 'er:camera-click',
  variations = {
    {filename = asset '/camera-click.ogg'},
    },
  volume = 1
	}}
  
-- -------------------------------------------------------------------------- --
-- Item                                                                       --
-- -------------------------------------------------------------------------- --

  
-- for _,control in pairs{
--   -- 'rotate',
--   -- 'build','mine',
--   -- 'open-gui',
--   -- 'move-down','move-left','move-right','move-up',
--   'clean-cursor',
--   } do
--   local name = 'er:controls:'..control
--   if not (data.raw['custom-input'] and data.raw['custom-input'][name]) then
--     data:extend{{
--       type                = 'custom-input' ,
--       name                = name           ,
--       key_sequence        = ''             , --nil is invalid
--       linked_game_control = control        }}
--     end
--   end


--[[
  
data:extend{{
  -- This allows loading the selection-tool type item when mods are removed
  type = 'selection-tool',
  name = ITEM_NAME,
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

--]]  

data:extend{{

  type = 'capsule',
  name = ITEM_NAME,
  
  -- flags = {"hidden", "only-in-cursor", "spawnable"},
  flags = {"hidden", "only-in-cursor"},
  flags = {"hidden", "only-in-cursor","not-stackable"}, --not stackable flag removes stack size number! :D
  -- draw_label_for_cursor_render = false,
  
  icons = ICONS_96,
  
  radius_color = {a=0}, -- don't show the radius
  
  stack_size = 1, -- abuse stacksize to show selection size?
  stackable = false,
  
  capsule_action = {
    type = 'throw',
    uses_stack = false,
    
    
    attack_parameters = {
      type = 'projectile',
      range = 1e7,
      cooldown = 2, -- 33 milliseconds
      
      ammo_type = {
        category = 'melee',
        }
      
      },
      
--[[
    attack_parameters = {
        type = "projectile",
        ammo_category = "grenade",
        cooldown = 30,
        projectile_creation_distance = 0.6,
        range = 20,
        ammo_type =
        {
          category = "grenade",
          target_type = "position",
          action =
          {
            {
              type = "direct",
              action_delivery =
              {
                type = "projectile",
                projectile = "cluster-grenade",
                starting_speed = 0.3
              }
            },
            -- {
              -- type = "direct",
              -- action_delivery =
              -- {
                -- type = "instant",
                -- target_effects =
                -- {
                  -- {
                    -- type = "play-sound",
                    -- sound = sounds.throw_projectile,
                  -- },
                -- }
              -- }
            -- }
          } 
        }
      },
      
--]]
      
    }
  

  }}
