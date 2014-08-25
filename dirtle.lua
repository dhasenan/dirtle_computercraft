-- dirtle: a dead reckoning turtle
-- Dirtle is a wrapper around turtle that uses dead reckoning to let you move
-- to particular locations based on the location you started at. This only
-- works if you *always* move using dirtle.
-- The same movement primitives are provided with dirtle as with turtle.
-- In addition, dirtle can move to a particular location and orientation
-- using coordinates relative to its starting position.

-- Dirtle can also blace ranges of blocks. Right now, it only does solid and
-- hollow blocks.

-- Dirtle does not handle pathfinding. It assumes it can move in straight lines
-- wherever it needs to go. It will make limited attempts to find alternate
-- routes, but every move it makes will be toward its destination. It can
-- sometimes find a zig-zag path, but it can't navigate to the other side of a
-- block.

-- Dirtle's coordinate system assumes it is facing toward (1, 0, 0). Its left
-- is (0, -1, 0); right is (0, 1, 0); up is (0, 0, 1); and so forth. It calls
-- its starting forward direction "north".



-- TODO:
-- * GPS integration
-- * Record where there are obstacles for more advanced pathfinding
-- * Block placing primitives (put a block at point P)
-- * Higher level block placing stuff (list of coords? ranges?)
-- * Client/server thing with GPS to record obstacles
-- * Record state so we can restart later


-- A coordinate is a 3-tuple representing a point in space.
-- It does not have any specified coordinate system.
Coord = {}
local _coordMt = {
  __index = Coord,
  __tostring = function(self)
    return string.format('(%d, %d, %d)', self.x, self.y, self.z)
  end
}
function Coord.new(x, y, z)
  local o = {}
  setmetatable(o, _coordMt)
  -- TODO should I only allow integer coordinates? That might make trouble for spheres...
  o.x = x
  o.y = y
  o.z = z
  return o
end

-- Add two coordinates together.
function Coord:plus(other)
  return Coord.new(self.x + other.x, self.y + other.y, self.z + other.z)
end

function Coord:minus(other)
  return Coord.new(self.x - other.x, self.y - other.y, self.z - other.z)
end

function Coord:mul(s)
  return Coord.new(self.x * s, self.y * s, self.z * s)
end

-- Get the Manhattan distance between this coordinate and another.
function Coord:manhattan(other)
  return math.abs(self.x - other.x) +
    math.abs(self.y - other.y) +
    math.abs(self.z - other.z)
end

function Coord:distance(other)
  local diff = self:minus(other)
  return math.sqrt(diff.x * diff.x + diff.y * diff.y + diff.z * diff.z)
end

function Coord:equals(other)
  if other == nil then
    return false
  end
  return self.x == other.x and self.y == other.y and self.z == other.z
end

function Coord:round()
  function roundInt(x)
    return math.floor(x + 0.5)
  end
  return Coord.new(roundInt(self.x), roundInt(self.y), roundInt(self.z))
end

-- Add two coordinates, generating a new coordinate representing their sum.

-- Direction constants.
NORTH = Coord.new( 0,  1,  0)
EAST  = Coord.new( 1,  0,  0)
SOUTH = Coord.new( 0, -1,  0)
WEST  = Coord.new(-1,  0,  0)
UP    = Coord.new( 0,  0,  1)
DOWN  = Coord.new( 0,  0, -1)

Shape = {}
local _shapeMt = {__index = Shape}
function Shape.new()
  local o = {}
  setmetatable(o, _shapeMt)
  return o
end

function Shape:intersect(other)
  return IntersectShape.new({self, other})
end

function Shape:union(other)
  return UnionShape.new({self, other})
end

function Shape:minus(other)
  return DifferenceShape.new(self, other)
end

function Shape:xor(other)
  return self:minus(other):union(other:minus(self))
end

function Shape:translate(coord)
  return TranslateShape.new(self, coord)
end

function Shape:contains(coord)
  return false
end

function Shape:coords_iter()
  return function()
    return nil
  end
end

function Shape:coords_list()
  local t = {}
  for c in self:coords_iter() do
    table.insert(t, c)
  end
end


-- A sphere.
SphereShape = {}
setmetatable(SphereShape, {__index = Shape})
local _sphereShapeMt = {__index = SphereShape}

function SphereShape.new(origin, radius)
  local o = {}
  setmetatable(o, _sphereShapeMt)
  o.origin = origin
  o.radius = radius
  return o
end

function SphereShape:contains(coord)
  -- A sphere is the intersection of two perpendicular cylinders.
  -- Or we can use x^2 + y^2 + z^2 = r^2.
  local d = coord:minus(self.origin)
  return math.pow(self.radius + 0.5, 2) >=
      (math.pow(d.x, 2) + math.pow(d.y, 2) + math.pow(d.z, 2))
end

function SphereShape:coords_iter()
  -- It's a *little* inefficient to filter out stuff from the bounding box,
  -- but a sphere is about half a cube, so this is good enough.
--  local iter = self.shape:coords_iter()
  local low = -1 * self.radius
  local high = self.radius
  local x = low
  local y = low
  local z = low
  return function()
    while z <= high do
      local c = Coord.new(x, y, z)
      x = x + 1
      if x > high then
        x = low
        y = y + 1
        if y > high then
          y = low
          z = z + 1
        end
      end
      if self:contains(c) then
        return c
      end
    end
    return nil
  end
end


--- A rectangular prism.
RectangleShape = {}
setmetatable(RectangleShape, {__index = Shape})
local _rectangleShapeMt = {__index = RectangleShape}

--- Create a RectangleShape.
-- @param start The coordinates of one corner of the prism.
-- @param finish The coordinates of the opposite corner of the prism.
function RectangleShape.new(start, finish)
  start, finish = normalizeCoordRange(start, finish)
  local o = {}
  setmetatable(o, _rectangleShapeMt)
  o.start = start
  o.finish = finish
  return o
end

function RectangleShape:contains(coord)
  return coord.x <= self.finish.x and
         coord.x >= self.start.x and
         coord.y <= self.finish.y and
         coord.y >= self.start.y and
         coord.z <= self.finish.z and
         coord.z >= self.start.z
end

function RectangleShape:coords_iter()
  local x = self.start.x
  local y = self.start.y
  local z = self.start.z
  return function()
    if z > self.finish.z then
      return nil
    end
    local c = Coord.new(x, y, z)
    x = x + 1
    if x > self.finish.x then
      x = self.start.x
      y = y + 1
      if y > self.finish.y then
        y = self.start.y
        z = z + 1
      end
    end
    return c
  end
end


--- A vertical cylinder.
CylinderShape = {}
setmetatable(CylinderShape, {__index = Shape})
local _cylinderShapeMt = {__index = CylinderShape}

--- Create a CylinderShape.
-- @param origin The center point of the lowest level of the cylinder.
-- @param radius The radius of the cylinder.
-- @param height The height of the cylinder.
function CylinderShape.new(origin, radius, height)
  local o = {}
  setmetatable(o, _cylinderShapeMt)
  o.origin = origin
  o.radius = radius
  o.height = height
  assert(o.origin ~= nil, 'nil origin')
  return o
end

function CylinderShape:contains(coord)
  if coord.z < self.origin.z or coord.z > self.origin.z + self.height then
    return false
  end
  -- A circle's border is defined as x^2 + y^2 = r^2.
  -- x^2 is always positive, so we can compare simply.
  -- To make the circles look fuller and less pointy, we add 0.5 to the radius.
  local offset = coord:minus(self.origin)
  return math.pow(offset.x, 2) + math.pow(offset.y, 2) <= math.pow(0.5 + self.radius, 2)
end

function CylinderShape:coords_iter()
  -- There are a few ways of doing this.
  -- Here, we are going in a square from -r to +r in each direction
  -- and filtering with contains().
  local level = 0
  local high = 1 + self.radius
  local low = -1 * high
  local x = low
  local y = low
  return function()
    while true do
      if level >= self.height then
        return nil
      end
      local c = Coord.new(self.origin.x + x, self.origin.y + y, self.origin.z + level)
      x = x + 1
      if x > high then
        x = low
        y = y + 1
        if y > high then
          y = low
          level = level + 1
        end
      end
      if self:contains(c) then
        return c
      end
    end
  end
end


-- A torus is a donut shape. If you take a circle and roll a sphere around it, everywhere the sphere
-- touched is a torus. It's defined by three values. The _center_ is the middle of the center hole.
-- The _major radius_ is the distance from the center to the middle of the ring. The _minor radius_
-- is the distance from the middle of the ring to the outer edge.
--
-- In this diagram of the center line of a torus:
-- |===*===|....O....|===*===|
--
-- The '.' signs represent points with no blocks. The 'O' is the center. The |====*====| part is
-- where the blocks go, with the '*' being the middle and the '|' being the edge. This is a major
-- radius of 'O....|===*' and a minor radius of '*===|'.
--
-- Alternatively, let's say you have a super-thin donut with a huge thick icing crust. The icing's
-- thickness is equal to the minor radius. The radius of the doughy ring is the major radius. The
-- radius of the hole is smaller than the major radius -- it's the difference between the major and
-- minor radiuses.
TorusShape = {}
setmetatable(TorusShape, {__index = Shape})
local _torusShapeMt = {__index = TorusShape}

-- Create a new torus shape with the given origin, major radius, and minor radius.
function TorusShape.new(origin, majorRadius, minorRadius)
  local o = {}
  setmetatable(o, _torusShapeMt)
  o.origin = origin
  o.majorRadius = majorRadius
  o.minorRadius = minorRadius
  return o
end

function TorusShape:contains(coord)
  -- A torus is essentially a sphere rolled around in a circle, or a series of overlapping spheres.
  -- If we can locate the right sphere, we can just see if that sphere contains this coordinate.
  -- We know its origin is on the center ring of the torus. It's on the plane of the torus (duh)
  -- and in line with the projection of this coordinate on that plane.
  -- So we just project the coord onto the torus's plane (z=0)...
  local shifted = coord:minus(self.origin)
  local relative = Coord.new(shifted.x, shifted.y, 0)
  -- Intercept it with the majorRadius ring...
  -- I have the current thing and need to scale it back. Its length is sqrt(x**2 + y**2), so I have
  -- to divide each coord part...
  local relLength = math.sqrt(shifted.x^2 + shifted.y^2)
  local ratio = self.majorRadius / relLength
  local sphereCenter = Coord.new(relative.x * ratio, relative.y * ratio, 0)
  -- And see if the distance from that point to the coordinate is small enough
  local distance = sphereCenter:distance(shifted)
  return distance <= self.minorRadius + 0.5
end

function TorusShape:coords_iter()
  -- Simple and stupid way.
  -- This is pretty expensive.
  local horizontalBound = self.majorRadius + self.minorRadius
  local verticalBound = self.minorRadius
  local x = -horizontalBound
  local y = -horizontalBound
  local z = -verticalBound

  return function()
    while z <= verticalBound do
      x = x + 1
      if x > horizontalBound then
        x = -horizontalBound
        y = y + 1
        if y > horizontalBound then
          y = -horizontalBound
          z = z + 1
          if z > verticalBound then
            return nil
          end
        end
      end
      local c = Coord.new(x, y, z)
      if self:contains(c) then
        return c
      end
    end
    return nil
  end
end



-- An IntersectShape is the intersection between a number of shapes. The intersection of a sphere
-- and a rectangular prism is a dome or a rectangular prism with a rounded top. You can intersect
-- any number of shapes (at least one, ideally).
-- A sphere is the intersection between two perpendicular cylinders.
IntersectShape = {}
setmetatable(IntersectShape, {__index = Shape})
local _intersectShapeMt = {__index = IntersectShape}

function IntersectShape.new(children)
  local o = {}
  setmetatable(o, _intersectShapeMt)
  o.children = children
  return o
end

function IntersectShape:contains(coord)
  for i=1, #self.children do
    if not self.children[i]:contains(coord) then
      return false
    end
  end
  return true
end

function IntersectShape:coords_iter()
  if #self.children == 0 then
    return function()
      return nil
    end
  end
  local iter = self.children[1]:coords_iter()
  return function()
    while true do
      local c = iter()
      if c == nil then
        return nil
      end
      if self:contains(c) then
        return c
      end
    end
  end
end


-- A union shape is the union of several shapes. It's the set of points contained in at least one of
-- its component (child) shapes. Use this to draw several shapes in one go, especially if they
-- intersect.
UnionShape = {}
setmetatable(UnionShape, {__index = Shape})
local _unionShapeMt = {__index = UnionShape}

function UnionShape.new(children)
  local o = {}
  setmetatable(o, _unionShapeMt)
  o.children = children
  return o
end

function UnionShape:contains(coord)
  for i=1, #self.children do
    if self.children[i]:contains(coord) then
      return true
    end
  end
  return false
end

function UnionShape:coords_iter()
  if #self.children == 0 then
    return function()
      return nil
    end
  end
  local i = 0
  local iter = nil
  return function()
    while true do
      if iter == nil then
        i = i + 1
        if i > #self.children then
          return nil
        end
        iter = self.children[i]:coords_iter()
      end
      local c = iter()
      if c == nil then
        iter = nil
      else
        local alreadySent = false
        for j = 1, i - 1 do
          if self.children[j]:contains(c) then
            alreadySent = true
          end
        end
        if not alreadySent then
          return c
        end
      end
    end
  end
end


-- A DifferenceShape is the difference between one shape and another. It's all points belonging to
-- the first shape not belonging to the second. You can use this to create hollow shapes -- an empty
-- sphere is just a sphere minus a slightly smaller sphere, for instance.
DifferenceShape = {}
setmetatable(DifferenceShape, {__index = Shape})
local _differenceShapeMt = {__index = DifferenceShape}

function DifferenceShape.new(minuend, subtrahend)
  local o = {}
  setmetatable(o, _differenceShapeMt)
  o.minuend = minuend
  o.subtrahend = subtrahend
  return o
end

function DifferenceShape:contains(coord)
  return self.minuend:contains(coord) and not self.subtrahend:contains(coord)
end

function DifferenceShape:coords_iter()
  local iter = self.minuend:coords_iter()
  return function()
    while true do
      local c = iter()
      if c == nil then
        return nil
      end
      if not self.subtrahend:contains(c) then
        return c
      end
    end
  end
end


-- A TranslateShape is a shape that's been moved. You could simply provide different coordinates in
-- the first place, but this might be more convenient sometimes.
TranslateShape = {}
setmetatable(TranslateShape, {__index = Shape})
local _translateShapeMt = {__index = TranslateShape}

function TranslateShape.new(shape, offset)
  local o = {}
  setmetatable(o, _translateShapeMt)
  o.shape = shape
  o.offset = offset
  return o
end

function TranslateShape:contains(coord)
  -- shape:c is now at shape:c+offset
  -- so inverse here
  return self.shape:contains(coord:plus(offset))
end

function TranslateShape:coords_iter()
  local iter = self.shape:coords_iter()
  return function()
    local c = iter()
    return c:plus(self.offset)
  end
end




local _dirtle_pos = Coord.new(0, 0, 0)
local _dirtle_facing = NORTH

function getPosition()
  return Coord.new(_dirtle_pos.x, _dirtle_pos.y, _dirtle_pos.z);
end

function getDirection()
  return Coord.new(_dirtle_facing.x, _dirtle_facing.y, _dirtle_facing.z);
end

function turnLeft()
  turtle.turnLeft()
  if _dirtle_facing:equals(NORTH) then
    _dirtle_facing = WEST
  elseif _dirtle_facing:equals(WEST) then
    _dirtle_facing = SOUTH
  elseif _dirtle_facing:equals(SOUTH) then
    _dirtle_facing = EAST
  else
    _dirtle_facing = NORTH
  end
  return true
end

function turnRight()
  turtle:turnRight()
  if _dirtle_facing:equals(NORTH) then
    _dirtle_facing = EAST
  elseif _dirtle_facing:equals(WEST) then
    _dirtle_facing = NORTH
  elseif _dirtle_facing:equals(SOUTH) then
    _dirtle_facing = WEST
  else
    _dirtle_facing = SOUTH
  end
  return true
end

function face(direction)
  if direction:equals(_dirtle_facing) then
    return true
  end
  if not (direction:equals(NORTH)
      or direction:equals(EAST)
      or direction:equals(SOUTH)
      or direction:equals(WEST)) then
    return false, "invalid direction, must be NORTH, SOUTH, EAST, or WEST"
  end
  -- We default to turning left. Not always optimal. Fix!
  if direction:equals(NORTH) and _dirtle_facing:equals(WEST) then
    turnRight()
  end
  if direction:equals(WEST) and _dirtle_facing:equals(SOUTH) then
    turnRight()
  end
  if direction:equals(SOUTH) and _dirtle_facing:equals(EAST) then
    turnRight()
  end
  if direction:equals(EAST) and _dirtle_facing:equals(NORTH) then
    turnRight()
  end
  for i=1,4 do
    if _dirtle_facing:equals(direction) then
      return true
    end
    turnLeft()
  end
  return false
end

function forward(count)
  if count == nil then count = 1 end
  for i=1, count do
    if turtle.forward() then
      _dirtle_pos = _dirtle_pos:plus(_dirtle_facing)
    else
      return i - 1
    end
  end
  return count
end

function back(count)
  if count == nil then count = 1 end
  dir = _dirtle_facing:mul(-1)
  for i=1, count do
    if turtle.forward() then
      _dirtle_pos = _dirtle_pos:plus(dir)
    else
      return i - 1
    end
  end
  return count
end

function up(count)
  if count == nil then count = 1 end
  for i=1, count do
    if turtle.up() then
      _dirtle_pos = _dirtle_pos:plus(UP)
    else
      return i - 1
    end
  end
  return count
end

function down(count)
  if count == nil then count = 1 end
  for i=1, count do
    if turtle.up() then
      _dirtle_pos = _dirtle_pos:plus(DOWN)
    else
      return i - 1
    end
  end
  return count
end

function left(count)
  turnLeft()
  s = forward(count)
  turnRight()
  return s
end

function right(count)
  turnLeft()
  s = forward(count)
  turnRight()
  return s
end

function north(count)
  face(NORTH)
  if _dirtle_facing:equals(NORTH) then
    forward(count)
  else
    error('failed to face NORTH')
  end
end

function south(count)
  face(SOUTH)
  if _dirtle_facing:equals(SOUTH) then
    forward(count)
  else
    error('failed to face SOUTH')
  end
end

function east(count)
  face(EAST)
  if _dirtle_facing:equals(EAST) then
    forward(count)
  else
    error('failed to face EAST')
  end
end

function west(count)
  face(WEST)
  if _dirtle_facing:equals(WEST) then
    forward(count)
  else
    error('failed to face WEST')
  end
end

function goTo(coords)
  coords = coords:round()
  while not _dirtle_pos.equals(coords) do
    local before = getPosition()
    diff = coords:minus(before)
    -- Try to go in each direction you can
    if diff.x < 0 then
      print('going west by ' .. tostring(math.abs(diff.x)))
      west(math.abs(diff.x))
    end
    if diff.x > 0 then
      print('going east by ' .. tostring(math.abs(diff.x)))
      east(diff.x)
    end
    if diff.y < 0 then
      -- -1 is left
      print('going south by ' .. tostring(math.abs(diff.y)))
      south(math.abs(diff.y))
    end
    if diff.y > 0 then
      print('going north by ' .. tostring(math.abs(diff.y)))
      north(diff.y)
    end
    if diff.z < 0 then
      print('going down by ' .. tostring(math.abs(diff.y)))
      down(math.abs(diff.z))
    end
    if diff.z > 0 then
      print('going up by ' .. tostring(math.abs(diff.y)))
      up(diff.z)
    end

    -- If we made any progress this time, we've got different obstacles for next time.
    -- Otherwise, we have the same obstacles and can't go on.
    print('got to ' .. tostring(getPosition()))
    local old = before:manhattan(coords)
    local new = getPosition():manhattan(coords)
    if new == 0 then
      return true
    end
    if new >= old then
      return false
    end
  end

  return true
end

-- Try to place a block from the currently selected item slot at the given
-- coordinates. This will move the turtle into position adjacent to that
-- block. Side preference is top, east, north, west, south, bottom.
-- If you are building a solid object with this, prefer building from the
-- bottom up.
function placeBlock(coords)
  coords = coords:round()
  print('trying to place block at ' .. tostring(coords))
  if turtle.getItemCount(turtle.getSelectedSlot()) == 0 then
    return false
  end
  if _dirtle_pos:equals(coords:plus(UP)) then
    print('placing block below')
    return turtle.placeDown()
  end
  if _dirtle_pos:equals(coords:plus(DOWN)) then
    print('placing block above')
    return turtle.placeUp()
  end
  for i, dir in pairs({EAST, NORTH, WEST, SOUTH}) do
    if coords:equals(_dirtle_pos:plus(dir)) then
      -- Turn in place!
      print('turning in place')
      face(dir)
      print('placing block')
      return turtle.place()
    end
  end
  -- Okay, travel. Prefer above, then lateral, then below.
  print('trying to go to ' .. tostring(coords:plus(UP)))
  if goTo(coords:plus(UP)) then
    print('placing block below after moving')
    return turtle.placeDown()
  end
  for dir in {EAST, NORTH, WEST, SOUTH} do
    print('trying to go to ' .. tostring(coords:plus(dir)))
    if goTo(coords:plus(dir)) then
      face(dir:times(-1))
      print('placing block after moving, laterally')
      return turtle.place()
    end
  end
  print('trying to go to ' .. tostring(coords:plus(DOWN)))
  if goTo(coords:plus(DOWN)) then
    print('placing block above after moving')
    return turtle.placeUp()
  end
  return false
end

function nextItem(indices)
  indices = indices or {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16}
  local s = 1
  for i=1, #indices do
    if indices[i] == turtle.getSelectedSlot() then
      s = i
      break
    end
  end
  for i=1, #indices do
    s = math.fmod(s, #indices) + 1
    if turtle.getItemCount(s) > 0 then
      turtle.select(s)
      return true
    end
  end
  return false
end

function normalizeCoordRange(start, finish)
  local s2 = Coord.new(0, 0, 0)
  local f2 = Coord.new(0, 0, 0)
  s2.x = math.min(start.x, finish.x)
  s2.y = math.min(start.y, finish.y)
  s2.z = math.min(start.z, finish.z)
  f2.x = math.max(start.x, finish.x)
  f2.y = math.max(start.y, finish.y)
  f2.z = math.max(start.z, finish.z)
  return s2, f2
end


-- Build the given shape in the world.
-- The optional itemIndices array indicates which item slots to pull blocks
-- from. It defaults to all slots.
function build(shape, itemIndices)
  local maxZ = 0
  for c in shape:coords_iter() do
    nextItem(itemIndices)
    print('item slot: ' .. tostring(turtle.getSelectedSlot()))
    if not placeBlock(c) then
      print('failed to place block at ' .. tostring(c))
    end
  end
  up()
  goTo(dirtle.Coord.new(0, 0, 0))
end
