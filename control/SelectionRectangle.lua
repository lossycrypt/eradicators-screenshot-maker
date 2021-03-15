-- (c) eradicator a.k.a lossycrypt, 2017-2020, not seperately licensable

--------------------------------------------------
-- A scripted selection rectangle usable with any tool.
--
-- Features:
--  + Resizable and movable via drag+drop
--  + Rendered via LuaRendering
--  + Heuristically detects "dragging" as a sequence of very fast clicks
--    like those produced by a capsule that fires every 2 ticks.
--
-- Usage:
--  SelectionRectangle.new(PlayerSpecification) creates a new rectangle instance.
--
--  SelectionRectangle.reclassify(rect) reattaches the metatable in on_load. 
--
--  SelectionRectangle.click(Position)
--
--  SelectionRectangle.draw() -- draws the rect into the world / updates the drawing.
--                            -- should be called after every click()
--
--  SelectionRectangle.reset() -- resets everything except the player reference



-- -------------------------------------------------------------------------- --
-- CONSTANTS                                                                  --
-- -------------------------------------------------------------------------- --

local erlib = require 'control/erlib-mini'
local Table = erlib.Table


-- Because factorio does not support real dragging it is extrapolated
-- from a series of very fast clicks. If there are no clicks for this
-- long (in ticks) then it is presumed that the player stopped dragging.
local DRAG_TIMEOUT = 60/4


local ACTIVE_RECT_COLOR = {r=0.8, g=0.8, b=0.8, a=0.8}

-- -------------------------------------------------------------------------- --
-- Helper                                                                     --
-- -------------------------------------------------------------------------- --

-- first return value is always smaller or equal to second
local function swap_if_gtr(a, b)
  if a <= b then return a, b
  else return b, a end
  end


-- 90°-stepped pre-calculated clockwise rotation
-- of (px,py) around (cx,cy) by @direction
--
-- @px, py: point to be rotated
-- @cx, cy: center point to rotate around (default: {0,0})
--
-- @returns (x,y) the rotated point
--
-- (originally from belt-router-3.lua)
local function point_rotate(direction, px, py, cx, cy)
  cx, cy = cx or 0, cy or 0
  local dx, dy = px - cx, py - cy -- vector (c -> p)
  if     direction == 0 then return cx + dx, cy + dy -- north =   0°
  elseif direction == 2 then return cx - dy, cy + dx -- east  =  90°
  elseif direction == 4 then return cx - dx, cy - dy -- south = 180°
  elseif direction == 6 then return cx + dy, cy - dx -- west  = 270°
  end end
  
  
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

  
  
-- -------------------------------------------------------------------------- --
-- Rect                                                                       --
-- -------------------------------------------------------------------------- --

-- Customized rectangle module for quick l,t,r,b access.

local Rect = {}

-- Rectangle-Point-Collision with build in rectangle resizing.
-- @tparam NaturalNumber offset Allows resizing the rectangle before checking.
function Rect.contains_point(rect, point, offset)
  offset = offset or 0 -- positive = larger rect, negative = smaller rect
  if  (rect.l - offset < point.x) and (rect.r + offset > point.x)
  and (rect.t - offset < point.y) and (rect.b + offset > point.y)
    then return true
    else return false
    end
  end
  
  
-- 
function Rect.from_point(point, radius)
  radius = radius or 0.01
  return {
    l = point.x - radius, t = point.y - radius,
    r = point.x + radius, b = point.y + radius,
    }
  end
  
  
-- a rectangle with NaturalNumber coordinates.
-- i.e. a "tile-aligned" rectangle.
function Rect.natural_rectangle_from_vector(vector)
  local l, r = swap_if_gtr(vector.a, vector.x)
  local t, b = swap_if_gtr(vector.b, vector.y)
  return {
    l = math.floor(l), t = math.floor(t),
    r = math.ceil (r), b = math.ceil (b),
    }
  end
  

-- a non-diagonal line between points "a" and "b"  
function Rect.from_line(a, b, width)
  width = width or 0.01
  -- vertical
  if a.x == b.x then
    return {
      l = a.x - width/2, t = a.y,
      r = b.x + width/2, b = b.y,
      }
  -- horizontal
  elseif a.y == b.y then
    return {
      l = a.x , t = a.y - width/2,
      r = b.x , b = b.y + width/2,
      }
  else
    error('Not a line')
    end
  end
  

function Rect.rotate_around_point(direction, rect, point)
  local r = {}
  r.l, r.t = point_rotate(direction, rect.l, rect.t, point.x, point.y)
  r.r, r.b = point_rotate(direction, rect.r, rect.b, point.x, point.y)
  return r
  end

  
-- -------------------------------------------------------------------------- --
-- SelectionRectangle (init)                                                  --
-- -------------------------------------------------------------------------- --

local SelectionRectangle = {}
local SelectionRectangle_mt = {__index = SelectionRectangle}


function SelectionRectangle.reclassify(srect)
  return srect and setmetatable(srect, SelectionRectangle_mt)
  end
  
  
function SelectionRectangle.new(pindex, p, surface)
  local self = SelectionRectangle.reclassify{
    pindex      = pindex ,
    player      = p      ,
    surface     = surface, -- optional, if nil player.surface is used instead
    render_uids = {}     ,
    }
  self:reset()
  return self
  end
  

function SelectionRectangle:reset()
  for k, uid in pairs(self.render_uids) do
    rendering.destroy(uid)
    self.render_uids[k] = nil
    end
  Table.clear(self, {'player', 'pindex', 'surface', 'render_uids'})
  end

  
function SelectionRectangle:purge_invalid_render_uids()
  for k, uid in pairs(self.render_uids) do
    if not rendering.is_valid(uid) then 
      self.render_uids[k] = nil
      end
    end
  end


  
-- -------------------------------------------------------------------------- --
-- SelectionRectangle (draw)                                                  --
-- -------------------------------------------------------------------------- --
  
-- draws the rectangle into the world
function SelectionRectangle:draw()
  -- update status before drawing
  self:purge_invalid_render_uids()
  self:update_outer_rect()
  --
  self:draw_outer_rect()
  self:draw_area_size_renders()
  end

  
function SelectionRectangle:draw_outer_rect()
  local uid = self.render_uids.outer_rect
  if not uid then
    uid = rendering.draw_rectangle {
      color            = ACTIVE_RECT_COLOR,
      width            = 2                ,
      filled           = false            ,
      left_top         = {0,0}            ,
      right_bottom     = {0,0}            ,
      surface          = self.surface or self.player.surface,
      time_to_live     = nil              ,
      players          = {self.player}    ,
      visible          = true             ,
      draw_on_ground   = false            ,
      only_in_alt_mode = false            ,
      }
    self.render_uids.outer_rect = uid
    end
  --
  rendering.set_left_top    (uid, {self.outer_rect.l, self.outer_rect.t})
  rendering.set_right_bottom(uid, {self.outer_rect.r, self.outer_rect.b})
  end
  
  
function SelectionRectangle:sget_text_render(name, orientation)
  local uid = self.render_uids[name]
  if not uid then
    uid = rendering.draw_text {
      text             = ''                                  ,
      surface          = self.surface or self.player.surface ,
      target           = {0,0}                               ,
      color            = ACTIVE_RECT_COLOR                   ,
      scale            = 1                                   ,
      font             = 'er:selection-rectangle-label-font' ,
      time_to_live     = nil                                 ,
      players          = {self.player}                       ,
      visible          = true                                ,
      draw_on_ground   = false                               ,
      orientation      = orientation                         ,
      alignment        = 'center'                            ,
      scale_with_zoom  = false                               ,
      only_in_alt_mode = false                               ,
      }
    self.render_uids[name] = uid
    end
  return uid
  end
  
  
function SelectionRectangle:update_text_render(name, position, text, orientation)
  local text_uid = self:sget_text_render(name, orientation)
  rendering.set_target(text_uid, position)
  rendering.set_text  (text_uid, text    )
  end
  
  
function SelectionRectangle:draw_area_size_renders()
  local width  = self.outer_rect.r - self.outer_rect.l
  local height = self.outer_rect.b - self.outer_rect.t
  local x_center = self.outer_rect.l + width  / 2
  local y_center = self.outer_rect.t + height / 2
  local x_text = ('← %d →'):format(width)
  local y_text = ('← %d →'):format(height)
  local offset = 1.3
  self:update_text_render(
    'top_label', {x_center, self.outer_rect.t - offset}, x_text, 0
    )
  self:update_text_render(
    'bottom_label', {x_center, self.outer_rect.b - offset/4}, x_text, 0
    )
  self:update_text_render(
    'left_label', {self.outer_rect.l - offset, y_center}, y_text, 0.75
    )
  self:update_text_render(
    'right_label', {self.outer_rect.r + offset, y_center}, y_text, 0.25
    )
  end

  
  
-- -------------------------------------------------------------------------- --
-- SelectionRectangle (selected_area)                                         --
-- -------------------------------------------------------------------------- --
  
function SelectionRectangle:update_outer_rect()
  self.outer_rect = Rect.natural_rectangle_from_vector(self)
  return self.outer_rect
  end
  
  
function SelectionRectangle:set_coordinates(l,t,r,b)
  -- (a,b) is the fixed corner
  self.a = l
  self.b = t
  -- (x,y) is the corner being dragged
  self.x = r or l -- init from point
  self.y = b or t
  end


function SelectionRectangle:get_outer_corner_rectangle(kx, ky)
  return Rect.from_point {x = self.outer_rect[kx], y = self.outer_rect[ky] }
  end
  
  
function SelectionRectangle:get_outer_edge_rectangle(ka, kb, kx, ky)
  return Rect.from_line(
    {x = self.outer_rect[ka], y = self.outer_rect[kb]},
    {x = self.outer_rect[kx], y = self.outer_rect[ky]}
    )
  end
  
  
function SelectionRectangle:get_selected_area()
  local rect
  if self.a then
    rect = self:update_outer_rect()
  else
    rect = {l = 0, t = 0, r = 0, b = 0}
    end
  local lt = {x = rect.l, y = rect.t}
  local rb = {x = rect.r, y = rect.b}
  return {
    lt = lt, left_top     = lt,
    rb = rb, right_bottom = rb,
    }
  end
  

--@future: dynamically change detection_radius based on currently selected area
--         i.e. larger area (== larger zoomout) gets larger radius
local corner_detection_radius = 0.99
local edge_detection_radius   = 0.99
function SelectionRectangle:click(position)
  -- @future: split click/drag?
  -- @future: condense collision check into lookup_table + function
  
  -- create new
  if (not self.a) then
    self:reset()
    self:set_coordinates(position.x, position.y)
    self.drag_mode, self.drag_x, self.drag_y = 'drag-corner', true, true
    
  -- change corner only when not dragging
  elseif (not self.last_click_tick) or (self.last_click_tick + DRAG_TIMEOUT < game.tick) then
    
    -- outside: ignore
    if self.outer_rect and not Rect.contains_point(self.outer_rect, position, 0) then 
      self.drag_mode, self.drag_x, self.drag_y = 'none', nil, nil
      return self
      end
    
    local outer_rect = self:update_outer_rect()
    
    local lt_corner = self:get_outer_corner_rectangle('l','t')
    local rt_corner = self:get_outer_corner_rectangle('r','t')
    local rb_corner = self:get_outer_corner_rectangle('r','b')
    local lb_corner = self:get_outer_corner_rectangle('l','b')
    
    local top_edge    = self:get_outer_edge_rectangle('l','t','r','t')
    local right_edge  = self:get_outer_edge_rectangle('r','t','r','b')
    local bottom_edge = self:get_outer_edge_rectangle('l','b','r','b')
    local left_edge   = self:get_outer_edge_rectangle('l','t','l','b')
    
    
    -- corner: left top
    if Rect.contains_point(lt_corner, position, corner_detection_radius) then
      self.a, self.b = outer_rect.r, outer_rect.b
      self.drag_mode, self.drag_x, self.drag_y = 'drag-corner', true, true
      
    -- corner: right top
    elseif Rect.contains_point(rt_corner, position, corner_detection_radius) then
      self.a, self.b = outer_rect.l, outer_rect.b
      self.drag_mode, self.drag_x, self.drag_y = 'drag-corner', true, true
      
    -- corner: right bottom
    elseif Rect.contains_point(rb_corner, position, corner_detection_radius) then
      self.a, self.b = outer_rect.l, outer_rect.t
      self.drag_mode, self.drag_x, self.drag_y = 'drag-corner', true, true
      
    -- corner: left bottom
    elseif Rect.contains_point(lb_corner, position, corner_detection_radius) then
      self.a, self.b = outer_rect.r, outer_rect.t
      self.drag_mode, self.drag_x, self.drag_y = 'drag-corner', true, true

      
    -- edge: top
    elseif Rect.contains_point(top_edge, position, edge_detection_radius) then
      self.a, self.b = outer_rect.l, outer_rect.b
      self.x         = outer_rect.r
      self.drag_mode, self.drag_x, self.drag_y = 'drag-edge', false, true

    -- edge: right
    elseif Rect.contains_point(right_edge, position, edge_detection_radius) then
      self.a, self.b = outer_rect.l, outer_rect.t
      self.y         = outer_rect.b
      self.drag_mode, self.drag_x, self.drag_y = 'drag-edge', true, false

    -- edge: bottom
    elseif Rect.contains_point(bottom_edge, position, edge_detection_radius) then
      self.a, self.b = outer_rect.l, outer_rect.t
      self.x         = outer_rect.r
      self.drag_mode, self.drag_x, self.drag_y = 'drag-edge', false, true

    -- edge: left
    elseif Rect.contains_point(left_edge, position, edge_detection_radius) then
      self.a, self.b = outer_rect.r, outer_rect.b
      self.y         = outer_rect.t
      self.drag_mode, self.drag_x, self.drag_y = 'drag-edge', true, false

      
    -- inside: move
    elseif Rect.contains_point(self.outer_rect, position, 0) then 
      self.drag_mode, self.drag_x, self.drag_y = 'move', nil, nil
      self.drag_start_position = position
      
      -- try to prevent visual rect resizing by perfectly clamping vector
      self.a, self.b = outer_rect.l + 0.5, outer_rect.t + 0.5
      self.x, self.y = outer_rect.r - 0.5, outer_rect.b - 0.5
      self.drag_dx, self.drag_dy = 0, 0 -- drag accumulator
      
      end
    end
    
  self.last_click_tick = game.tick
  self.last_click_position = position
  
    
  if self.drag_mode == 'drag-corner' or self.drag_mode == 'drag-edge' then
    if self.drag_x then self.x = position.x end
    if self.drag_y then self.y = position.y end
    
  elseif self.drag_mode == 'move' and self.drag_start_position then
    -- V2: Accumulate drag and snap on distance > 1
    self.drag_dx = self.drag_dx + (position.x - self.drag_start_position.x)
    self.drag_dy = self.drag_dy + (position.y - self.drag_start_position.y)
    self.drag_start_position = position
    local dx; dx, self.drag_dx = math.modf(self.drag_dx) -- integer + rest
    self.a, self.x = self.a + dx, self.x + dx
    local dy; dy, self.drag_dy = math.modf(self.drag_dy)
    self.b, self.y = self.b + dy, self.y + dy
  
    -- V1: Instant apply (sometimes causes area size change)
    -- local dx = position.x - self.drag_start_position.x
    -- local dy = position.y - self.drag_start_position.y
    -- self.a, self.b = self.a + dx, self.b + dy
    -- self.x, self.y = self.x + dx, self.y + dy
    -- self.drag_start_position = position
    end
    
  -- self:draw()
  -- blip({self.a, self.b}, self.player)
  -- blip({self.x, self.y}, self.player)
  return self
  end



-- -------------------------------------------------------------------------- --
-- SelectionRectangle (rotate)                                                --
-- -------------------------------------------------------------------------- --

function SelectionRectangle:rotate_right()
  return self:rotate_by_direction(defines.direction.east) -- "2"
  end
  
  
function SelectionRectangle:rotate_left()
  return self:rotate_by_direction(defines.direction.west) -- "6"
  end
  
  
function SelectionRectangle:rotate_by_direction(direction)
  -- Skip when player is not "holding down" the mouse button.
  if (not self.last_click_tick)
  or (self.last_click_tick + DRAG_TIMEOUT < game.tick) then
    return self
    end
  
  local center = {
    x = math.floor(self.last_click_position.x) + 0.5,
    y = math.floor(self.last_click_position.y) + 0.5,
    }
    
  local r = Rect.rotate_around_point(direction, self.outer_rect, center)
  
  if self.drag_mode == 'move' then
    self:set_coordinates(r.l, r.t, r.r, r.b)
    
  elseif self.drag_mode == 'drag-edge' then
    self:set_coordinates(r.l, r.t, r.r, r.b)
    self.last_click_tick = nil -- hackfix: indirectly reset the dragged edge
    
  elseif self.drag_mode == 'drag-corner' then
    self.a, self.b = point_rotate(direction, self.a, self.b, center.x, center.y)
    end
    
  self:update_outer_rect()
  
  -- self:draw()
  -- blip(center, self.player)
  -- blip({self.a, self.b}, self.player)
  -- blip({self.x, self.y}, self.player)
  return self
  end


  
return SelectionRectangle