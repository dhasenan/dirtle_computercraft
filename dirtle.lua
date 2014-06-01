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
  o.x = x
  o.y = y
  o.z = z
  return o
end

function Coord:add(other)
  return Coord.new(self.x + other.x, self.y + other.y, self.z + other.z)
end

function Coord:plus(other)
  return self:add(other)
end

function Coord:sub(other)
  return Coord.new(self.x - other.x, self.y - other.y, self.z - other.z)
end

function Coord:minus(other)
  return self:sub(other)
end

function Coord:mul(s)
  return Coord.new(self.x * s, self.y * s, self.z * s)
end

function Coord:equals(other)
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
NORTH = Coord.new( 1,  0,  0)
EAST  = Coord.new( 0,  1,  0)
SOUTH = Coord.new(-1,  0,  0)
WEST  = Coord.new( 0, -1,  0)
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
  return XorShape.new(self, other)
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
        return c
      end
    end
  end
end


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


RectangleShape = {}
setmetatable(RectangleShape, {__index = Shape})
local _rectangleShapeMt = {__index = RectangleShape}

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


-- A vertical cylinder. The origin of the cylinder is the center of the lowest level.
CylinderShape = {}
setmetatable(CylinderShape, {__index = Shape})
local _cylinderShapeMt = {__index = CylinderShape}

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


SphereShape = {}
setmetatable(SphereShape, {__index = Shape})
local _sphereShapeMt = {__index = SphereShape}

function SphereShape.new(shape, origin, radius)
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
  local iter = self.shape:coords_iter()
  local low = -1 * self.radius
  local high = self.radius
  local x = low
  local y = low
  local z = low
  return function()
    while x <= high or y <= high or z <= high do
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





local _dirtle_pos = Coord.new(0, 0, 0)
local _dirtle_facing = NORTH

function turnLeft()
  turtle.turnLeft()
  if _dirtle_facing.equals(NORTH) then
    _dirtle_facing = WEST
  elseif _dirtle_facing.equals(WEST) then
    _dirtle_facing = SOUTH
  elseif _dirtle_facing.equals(SOUTH) then
    _dirtle_facing = EAST
  else
    _dirtle_facing = NORTH
  end
  return true
end

function turnRight()
  turtle.turnRight()
  if _dirtle_facing.equals(NORTH) then
    _dirtle_facing = EAST
  elseif _dirtle_facing.equals(WEST) then
    _dirtle_facing = NORTH
  elseif _dirtle_facing.equals(SOUTH) then
    _dirtle_facing = WEST
  else
    _dirtle_facing = SOUTH
  end
  return true
end

function face(direction)
  if not direction.equals(NORTH)
      or not direction.equals(EAST)
      or not direction.equals(SOUTH)
      or not direction.equals(WEST) then
    return false, "invalid direction, must be NORTH, SOUTH, EAST, or WEST"
  end
  for i=1,4 do
    if not _dirtle_facing.equals(direction) then
      turnLeft()
    end
  end
  return _dirtle_facing.equals(direction)
end

function forward(count)
  if count == nil then count = 1 end
  for i=1, count do
    if turtle.forward() then
      _dirtle_pos = coord_add(_dirtle_pos, _dirtle_facing)
    else
      return i - 1
    end
  end
  return count
end

function back(count)
  if count == nil then count = 1 end
  dir = coord_mul(_dirtle_facing, -1)
  for i=1, count do
    if turtle.forward() then
      _dirtle_pos = coord_add(_dirtle_pos, dir)
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
      _dirtle_pos = coord_add(_dirtle_pos, UP)
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
      _dirtle_pos = coord_add(_dirtle_pos, UP)
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

function goTo(coords)
  while not _dirtle_pos.equals(coords) do
    progress = 0
    diff = coord_sub(coords, _dirtle_pos)
    -- Try to go in each direction you can
    if diff.x < 0 then
      progress = progress + back(-1 * diff.x)
    end
    if diff.x > 0 then
      progress = progress + forward(diff.x)
    end
    if diff.y < 0 then
      -- -1 is left
      progress = progress + left(-1 * diff.y)
    end
    if diff.y > 0 then
      progress = progress + right(diff.y)
    end
    if diff.z < 0 then
      progress = progress + down(-1 * diff.z)
    end
    if diff.z > 0 then
      progress = progress + right(diff.z)
    end

    -- If we made any progress this time, we've got different obstacles for
    -- next time. Otherwise, we have the same obstacles and can't go on.
    if progress == 0 then
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
  if turtle.getItemCount(turtle.getSelectedSlot()) == 0 then
    return false
  end
  if _dirtle_pos:equals(coords:plus(UP)) then
    turtle.placeDown()
    return true
  end
  if _dirtle_pos:equals(coords:plus(DOWN)) then
    turtle.placeUp()
    return true
  end
  for dir in {EAST, NORTH, WEST, SOUTH} do
    if _dirtle_pos:equals(coords:plus(dir)) then
      -- Turn in place!
      face(dir:times(-1))
      return turtle.place()
    end
  end
  -- Okay, travel. Prefer above, then lateral, then below.
  if goTo(coords:plus(UP)) then
    return turtle.placeDown()
  end
  for dir in {EAST, NORTH, WEST, SOUTH} do
    if goTo(coords:plus(dir)) then
      face(dir:times(-1))
      return turtle.place()
    end
  end
  if goTo(coords:plus(DOWN)) then
    return turtle.placeUp()
  end
  return false
end

function getPosition()
  return Coord.new(_dirtle_pos.x, _dirtle_pos.y, _dirtle_pos.z);
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
    s = s + 1
    s = math.fmod(s, #indices) + 1
    if s > 16 then s = 2 end
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
    if maxZ < c.z then maxZ = c.z end
    if not nextItem(itemIndices) then
      -- Rise above the shenanigans
      goUp(1 + maxZ - getPosition().z)
      goTo(dirtle.coord(0, 0, 0))
    end
    placeBlock(c)
  end
end

function buildWithStochasticTorches(shape, torchIndices)
  -- Input management! Sort out our torches and blocks
  if torchIndices == nil then
    torchIndices = {1}
  end
  torchIndices = table.sort(torchIndices)
  local k = 1
  local blockIndices = {}
  for i=1, 16 do
    if i == torchIndices[k] then
      k = k + 1
    else
      table.insert(blockIndices, i)
    end
  end
  if #blockIndices == 0 then
    return 0
  end

  -- The 'crown' of the shape is any block with no block above it.
  -- This is perhaps a bit too inclusive; a one-block gap will be a
  -- candidate for getting a torch, even though it can't spawn a mob.
  -- (Except maybe a chicken.)
  -- We will put torches on some arbitrary subset of the crown.
  local crown = shape:difference(shape:translate(Coord.new(0, 0, -1)))
  local maxZ = 0
  for c in shape:coords_iter() do
    if maxZ < c.z then maxZ = c.z end
    if not nextItem(itemIndices) then
      -- Rise above the shenanigans
      goUp(1 + maxZ - getPosition().z)
      goTo(dirtle.coord(0, 0, 0))
    end
    placeBlock(c)
    if crown:contains(c) and math.random(20) == 1 then
      local s = turtle.getSelectedSlot()
      nextItem(torchIndices)
      placeBlock(c:plus(UP))
      turtle.select(s)
    end
  end
end
