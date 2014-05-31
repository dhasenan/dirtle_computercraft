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
local _coordMt = {__index = Coord}
function Coord:new(x, y, z)
  local o = {}
  setmetatable(o, _coordMt)
  o.x = x
  o.y = y
  o.z = z
  return o
end

function Coord:add(other)
  return Coord:new(self.x + other.x, self.y + other.y, self.z + other.z)
end

function Coord:sub(other)
  return Coord:new(self.x - other.x, self.y - other.y, self.z - other.z)
end

function Coord:mul(s)
  return Coord:new(self.x * s, self.y * s, self.z * s)
end

function Coord:equals(other)
  return self.x == other.x and self.y == other.y and self.z == other.z
end

function Coord:round()
  function roundInt(x)
    return math.floor(x + 0.5)
  end
  return Coord:new(roundInt(self.x), roundInt(self.y), roundInt(self.z))
end

-- Add two coordinates, generating a new coordinate representing their sum.

-- Direction constants.
NORTH = Coord:new( 1,  0,  0)
EAST  = Coord:new( 0,  1,  0)
SOUTH = Coord:new(-1,  0,  0)
WEST  = Coord:new( 0, -1,  0)
UP    = Coord:new( 0,  0,  1)
DOWN  = Coord:new( 0,  0, -1)

Shape = {}
local _shapeMt = {__index = Shape}
function Shape:new()
  local o = {}
  setmetatable(o, _shapeMt)
  return o
end

function Shape:intersect(other)
  return IntersectShape:new({self, other})
end

function Shape:union(other)
  return UnionShape:new({self, other})
end

function Shape:minus(other)
  return DifferenceShape:new(self, other)
end

function Shape:xor(other)
  return XorShape:new(self, other)
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

function IntersectShape:new(children)
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

function UnionShape:new(children)
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

function DifferenceShape:new(minuend, subtrahend)
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

function RectangleShape:new(start, finish)
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
         coord.y <= self.start.y and
         coord.y >= self.start.y and
         coord.z <= self.start.z and
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
    local c = Coord:new(x, y, z)
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

function CylinderShape:new(origin, radius, height)
  local o = {}
  setmetatable(o, _cylinderShapeMt)
  o.origin = center
  o.radius = radius
  o.height = height
  return o
end

function CylinderShape:contains(coord)
  if coord.z < self.origin.z or coord.z > self.origin.z + self.height then
    return false
  end
  -- A circle's border is defined as x^2 + y^2 = r^2.
  -- x^2 is always positive, so we can compare simply:
  local offset = coord:minus(self.origin)
  return math.pow(offset.x, 2) + math.pow(offset.y, 2) <= math.pow(self.radius, 2)
end

function CylinderShape:coords_iter()
  -- There are a few ways of doing this.
  -- Here, we are going in a square from -r to +r in each direction
  -- and filtering with contains().
  local level = 0
  local x = -1 * self.radius
  local y = -1 * self.radius
  return function()
    while true do
      if level >= self.height then
        return nil
      end
      local c = Coord:new(self.origin.x + x, self.origin.y + y, self.origin.z + level)
      x = x + 1
      if x > self.radius then
        x = -1 * self.radius
        y = y + 1
        if y > self.radius then
          y = -1 * self.radius
          level = level + 1
        end
      end
      if self:contains(c) then
        return c
      end
    end
  end
end


local _dirtle_pos = Coord:new(0, 0, 0)
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
  return Coord:new(_dirtle_pos.x, _dirtle_pos.y, _dirtle_pos.z);
end

function nextItem()
  local s = turtle.getSelectedSlot()
  for i=1, 16 do
    s = s + 1
    if s > 16 then s = 2 end
    if turtle.getItemCount(s) > 0 then
      turtle.select(s)
      return true
    end
  end
  return false
end

function normalizeCoordRange(start, finish)
  local s2 = Coord:new(0, 0, 0)
  local f2 = Coord:new(0, 0, 0)
  s2.x = math.min(start.x, finish.x)
  s2.y = math.min(start.y, finish.y)
  s2.z = math.min(start.z, finish.z)
  f2.x = math.max(start.x, finish.x)
  f2.y = math.max(start.y, finish.y)
  f2.z = math.max(start.z, finish.z)
  return s2, f2
end


function build(shape)
end

-- 
function buildSolidBlock(start, finish, afterPlace)
  start, finish = normalizeCoordRange(start, finish)
  local size = finish:minus(start)
  turtle.select(1)
  goTo(opts.start:plus(dirtle.UP))
  local l = size.x
  local w = size.y
  local h = size.z
  local block = 0
  for x=1, l do
    for y=1, w do
      for z=1, h do
        goTo(dirtle.coord(x, y, z + 1))
        if not nextItem() then
          -- So as not to strain the pathfinding much, first go up above the project.
          -- Then head home.
          goTo(dirtle.coord(x, y, h + 2))
          goTo(dirtle.coord(0, 0, 0))
        end
        placeDown()
        if afterPlace ~= nil then
          afterPlace()
        end
        block = block + 1
      end
    end
  end
end

function buildHollowBlock(start, finish, afterPlace)
  start, finish = normalizeCoordRange(start, finish)
  -- Build the lower platform. Leave the margin alone -- one primary usecase of afterPlace is to
  -- add torches, and that doesn't work so well otherwise.
  buildSolidBlock(
    Coord:new(start.x + 1, start.y + 1, start.z),
    Coord:new(finish.x - 1, finish.y - 1, start.z),
    afterPlace)
  -- Same for the top
  buildSolidBlock(
    Coord:new(start.x + 1, start.y + 1, finish.z),
    Coord:new(finish.x - 1, finish.y - 1, finish.z),
    afterPlace)

  -- Now build the left and right walls
  buildSolidBlock(
    Coord:new(start.x, start.y, start.z),
    Coord:new(start.x, finish.y, finish.z),
    afterPlace)
  buildSolidBlock(
    Coord:new(finish.x, start.y, start.z),
    Coord:new(finish.x, finish.y, finish.z),
    afterPlace)

  -- Now the front and back. Here, the corners have already been filled.
  -- So we have to be careful not to fill those spaces.
  buildSolidBlock(
    Coord:new(start.x + 1, start.y, start.z),
    Coord:new(finish.x - 1, start.y, finish.z),
    afterPlace)
  buildSolidBlock(
    Coord:new(start.x + 1, finish.y, start.z),
    Coord:new(finish.x - 1, finish.y, finish.z),
    afterPlace)
end

-- Create a hollow block at the given location with torches inside and out.
-- It's assumed that the turtle has torches in its inventory at slot 1.
-- It will attempt to place a torch at every tenth block on average --
-- specifically, on alternating rows, it will place a torch every five blocks.
-- This is the minimum to ensure safety during the build, but you should be able to remove
-- alternating rows at the end.
function buildHollowBlockWithTorches(start, finish)
  start, finish = normalizeCoordRange(start, finish)
  local count = 0
  -- We need a torch every 13-ish blocks in the end.
  -- While building, we should err on the side of caution. Turtles aren't speed demons. 
  -- Specifically, we want to add Steiner lights so that we don't have shadows while building.
  -- If we just put down a torch every 13th block, we will end up with shadows temporarily. About
  -- half the time, the turtle will be in spawning territory.
  --
  -- Specifically, in the middle of building, we'll see a light like this:
  --
  -- 89ABCD=DCBA9889ABCD=DCBA98
  --  89ABCDCBA98  89ABCDCBA98
  --   89ABCBA98    89ABCBA98
  --    89ABA98        *[empty...]
  --
  -- The * is where the turtle is now, the = is where there's a torch, and the unmarked areas allow
  -- mobs to spawn.
  --
  -- If we put torches closer together (every 9th block), we reduce this issue:
  -- ABCD=DCBAABCD=DCBA98
  -- 9ABCDCBA99ABCDCBA98
  -- 89ABCBA9889ABCBA98
  --  89ABA98    *[empty...]
  --
  -- But this means we need to put down torches every third row. We could squish them slightly
  -- closer together; 9/3 and 7/4 are options, as is 11/1.
  -- We're also a bit unsafe during construction.
  -- 7/1 is the minimum perfectly safe option. 5/2 also works and is slightly lighter on torches.
  function willBuildThisSpot(lastBuiltAt)
    if lastBuiltAt.z == finish.z then
      return false
    end
    if lastBuiltAt.z == start.z then
      if lastBuiltAt.x == start.x or lastBuiltAt.x == finish.x then
        return true
      end
      if lastBuiltAt.y == start.y or lastBuiltAt.y == finish.y then
        return true
      end
    end
    return false
  end
  function placeTorch(lastBuiltAt)
    local s = turtle.getSelectedSlot()
    turtle.select(1)
    placeBlock(lastBuiltAt:plus(UP))
    turtle.select(s)
  end
  function maybeBuildTorch(lastBuiltAt)

  end
end
