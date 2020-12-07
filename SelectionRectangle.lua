
-- -------------------------------------------------------------------------- --
-- CONSTANTS                                                                  --
-- -------------------------------------------------------------------------- --

local erlib = require 'minilib'

local Table = erlib.Table


-- -------------------------------------------------------------------------- --
-- Helper                                                                     --
-- -------------------------------------------------------------------------- --


-- first return value is always smaller or equal to second
local function swap_if_gtr(a, b)
  if a <= b then return a, b
  else return b, a end
  end

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
  -- radius = radius or 1.25
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
  
-- -------------------------------------------------------------------------- --
-- SelectionRectangle                                                         --
-- -------------------------------------------------------------------------- --


local SelectionRectangle = {}
local obj_mt = {__index = SelectionRectangle}


setmetatable(SelectionRectangle, {
  __call = function(_)
    error('not implemented')
    end,
  })

  
-- initialize new
function SelectionRectangle.new(pspec)
  local p = game.get_player(pspec)
  local self = {
    player  = p,
    pindex  = p.index,
    surface = p.surface,
    render_uids = {},
    }
  return setmetatable(self, obj_mt)
  end
  
  
--
function SelectionRectangle:set_coordinates(l,t,r,b)
  -- (a,b) is the fixed corner
  self.a = l
  self.b = t
  -- (x,y) is the corner being dragged
  self.x = r or l -- init from point
  self.y = b or t
  end

--
local keep = {
  player = true,
  pindex = true,
  surface = true,
  render_uids = true,
  }
function SelectionRectangle:reset()
  -- @todo: surface and player are permanent?
  for k, uid in pairs(self.render_uids) do
    rendering.destroy(uid)
    self.render_uids[k] = nil
    end
  for k in pairs(self) do
    if not keep[k] then
      self[k] = nil
      end
    end
  end
  
  
-- attach meta to old
function SelectionRectangle.reclassify(srect)
  return setmetatable(srect, obj_mt)
  end
  
  
-- remove old rendering ids
function SelectionRectangle:purge_invalid_render_uids()
  for k, uid in pairs(self.render_uids) do
    if not rendering.is_valid(uid) then 
      self.render_uids[k] = nil
      end
    end
  end
  

  

  

-- draws the rectangle into the world
local COLOR_WHITE = {r=1, g=1, b=1}
function SelectionRectangle:draw()
  --
  self:purge_invalid_render_uids()
  local uids = self.render_uids
  --
  if not uids.outer_rect then
    uids.outer_rect = rendering.draw_rectangle {
      color            = COLOR_WHITE     ,
      width            = 2               ,
      filled           = false           ,
      left_top         = {0,0}           ,
      right_bottom     = {0,0}           ,
      surface          = self.surface    ,
      time_to_live     = nil             ,
      players          = {self.player}   ,
      visible          = true            ,
      draw_on_ground   = false           ,
      only_in_alt_mode = false           ,
      }
    end
  --
  self:update_outer_rect()
  -- print(serpent.block(self))
  rendering.set_left_top    (uids.outer_rect, {self.outer_rect.l, self.outer_rect.t})
  rendering.set_right_bottom(uids.outer_rect, {self.outer_rect.r, self.outer_rect.b})
  end
  

function SelectionRectangle:get_outer_corner_rectangle(kx, ky)
  return Rect.from_point {x = self.outer_rect[kx], y = self.outer_rect[ky] }
  end

-- a non-diagonal line between "a" and "b"  
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
  
  
function SelectionRectangle:get_outer_edge_rectangle(ka, kb, kx, ky)
  return Rect.from_line(
    {x = self.outer_rect[ka], y = self.outer_rect[kb]},
    {x = self.outer_rect[kx], y = self.outer_rect[ky]}
    )
  end
  
  
function SelectionRectangle:update_outer_rect()
  self.outer_rect = Rect.natural_rectangle_from_vector(self)
  return self.outer_rect
  end

function SelectionRectangle:click(position)
  -- @future: split click/drag?
  
  local drag_timeout = 60/4 -- ~0.25 seconds
  local corner_detection_radius = 0.99
  local edge_detection_radius   = 0.99
  
  
  -- 却下！ trying to filter out "outside" clicks also blocks very fast mouse movement.
  
  -- if self.outer_rect and not Rect.contains_point(self.outer_rect, position, 5*corner_detection_radius) then 
    -- print('outside')
    -- return
    -- end
  
  -- create new
  if (not self.a) then
    self:reset()
    self:set_coordinates(position.x, position.y)
    self.drag_mode, self.drag_x, self.drag_y = 'drag', true, true
    
    
  -- change corner only when not dragging
  elseif (not self.last_click_tick) or (self.last_click_tick + drag_timeout < game.tick) then
    
    -- outside: ignore
    if self.outer_rect and not Rect.contains_point(self.outer_rect, position, 0) then 
      self.drag_mode, self.drag_x, self.drag_y = 'none', nil, nil
      return
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
      self.drag_mode, self.drag_x, self.drag_y = 'drag', true, true
      
    -- corner: right top
    elseif Rect.contains_point(rt_corner, position, corner_detection_radius) then
      self.a, self.b = outer_rect.l, outer_rect.b
      self.drag_mode, self.drag_x, self.drag_y = 'drag', true, true
      
    -- corner: right bottom
    elseif Rect.contains_point(rb_corner, position, corner_detection_radius) then
      self.a, self.b = outer_rect.l, outer_rect.t
      self.drag_mode, self.drag_x, self.drag_y = 'drag', true, true
      
    -- corner: left bottom
    elseif Rect.contains_point(lb_corner, position, corner_detection_radius) then
      self.a, self.b = outer_rect.r, outer_rect.t
      self.drag_mode, self.drag_x, self.drag_y = 'drag', true, true
    
    
    -- edge: top
    elseif Rect.contains_point(top_edge, position, edge_detection_radius) then
      self.a, self.b = outer_rect.l, outer_rect.b
      self.x         = outer_rect.r
      self.drag_mode, self.drag_x, self.drag_y = 'drag', false, true

    -- edge: right
    elseif Rect.contains_point(right_edge, position, edge_detection_radius) then
      self.a, self.b = outer_rect.l, outer_rect.t
      self.y         = outer_rect.b
      self.drag_mode, self.drag_x, self.drag_y = 'drag', true, false

    -- edge: bottom
    elseif Rect.contains_point(bottom_edge, position, edge_detection_radius) then
      self.a, self.b = outer_rect.l, outer_rect.t
      self.x         = outer_rect.r
      self.drag_mode, self.drag_x, self.drag_y = 'drag', false, true

    -- edge: left
    elseif Rect.contains_point(left_edge, position, edge_detection_radius) then
      self.a, self.b = outer_rect.r, outer_rect.b
      self.y         = outer_rect.t
      self.drag_mode, self.drag_x, self.drag_y = 'drag', true, false

    -- inside: move
    elseif Rect.contains_point(self.outer_rect, position, 0) then 
      self.drag_mode, self.drag_x, self.drag_y = 'move', nil, nil
      self.last_click_position = position
      
      -- try to prevent visual rect resizing by perfectly clamping vector
      -- @todo: doesn't work perfectly yet. a center + fixed rect approach might work better.
      self.a, self.b = outer_rect.l + 0.5, outer_rect.t + 0.5
      self.x, self.y = outer_rect.r - 0.5, outer_rect.b - 0.5
      
      self.drag_dx = 0 -- drag accumulator
      self.drag_dy = 0
      
      end
    end
    
  self.last_click_tick = game.tick
    
  if self.drag_mode == 'drag' then
    if self.drag_x then self.x = position.x end
    if self.drag_y then self.y = position.y end
    
  elseif self.drag_mode == 'move' and self.last_click_position then
  
    -- V2: Accumulate drag and snap on distance > 1
    self.drag_dx = self.drag_dx + (position.x - self.last_click_position.x)
    self.drag_dy = self.drag_dy + (position.y - self.last_click_position.y)
    self.last_click_position = position
    local dx; dx, self.drag_dx = math.modf(self.drag_dx) -- integer + rest
    self.a, self.x = self.a + dx, self.x + dx
    local dy; dy, self.drag_dy = math.modf(self.drag_dy)
    self.b, self.y = self.b + dy, self.y + dy
  
    -- V1: Instant apply (sometimes causes area size change)
    -- local dx = position.x - self.last_click_position.x
    -- local dy = position.y - self.last_click_position.y
    -- self.a, self.b = self.a + dx, self.b + dy
    -- self.x, self.y = self.x + dx, self.y + dy
    -- self.last_click_position = position
    end
    
  self:draw()
  -- blip({self.a, self.b}, self.player)
  -- blip({self.x, self.y}, self.player)
  
  end
  
  
return SelectionRectangle