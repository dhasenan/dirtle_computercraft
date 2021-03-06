require('dirtle')
-- os.loadAPI() loads stuff into a new namespace.
-- require() loads stuff into the global namespace.
-- This is a hack to make the API work as we want.
local dirtle = _G


-- For debugging: print out a shape line by line, from the bottom up.
function plot(shape)
  local min = dirtle.Coord.new(0, 0, 0)
  local max = dirtle.Coord.new(0, 0, 0)
  print()
  for c in shape:coords_iter() do
    if c.x > max.x then
      max.x = c.x
    end
    if c.y > max.y then
      max.y = c.y
    end
    if c.z > max.z then
      max.z = c.z
    end
    if c.x < min.x then
      min.x = c.x
    end
    if c.y < min.y then
      min.y = c.y
    end
    if c.z < min.z then
      min.z = c.z
    end
  end

  for z = min.z, max.z do
    for y = min.y, max.y do
      local line = ""
      for x = min.x, max.x do
        if shape:contains(dirtle.Coord.new(x, y, z)) then
          line = line .. "x"
        else
          line = line .. " "
        end
      end
      print(line)
    end
  end
end

--[[
local turtle = {}
turtle.x = 0
turtle.y = 0
turtle.z = 0
turtle.facing = 0

turtle.up = function()
  turtle.z = turtle.z + 1
end

turtle.down = function()
  turtle.z = turtle.z - 1
end

local qcirc = math.pi / 2.0
turtle.turnLeft = function()
  turtle.facing = turtle.facing - qcirc
end

turtle.turnRight = function()
  turtle.facing = turtle.facing + qcirc
end

turtle.forward = function()
  turtle.y = turtle.y + math.cos(turtle.facing)
  turtle.x = turtle.x + math.sin(turtle.facing)
end

turtle.left = function()
  turtle.y = turtle.y + math.cos(turtle.facing - qcirc)
  turtle.x = turtle.x + math.sin(turtle.facing - qcirc)
end

turtle.right = function()
  turtle.y = turtle.y + math.cos(turtle.facing + qcirc)
  turtle.x = turtle.x + math.sin(turtle.facing + qcirc)
end

turtle.back = function()
  turtle.y = turtle.y - math.cos(turtle.facing)
  turtle.x = turtle.x - math.sin(turtle.facing)
end

turtle.placeDown = function()
  local layerBelow = turtle.blocks[turtle.z - 1]
  if layerBelow == nil then
    layerBelow = {}
    turtle.blocks[turtle.z - 1] = {}
  end
  local rank = layerBelow[turtle.x]
  if rank == nil then
    rank = {}
    layerBelow[turtle.x] = {}
  end
  local cell = rank[turtle.y]
  if cell ~= nil then
    return false
  end
end
--]]


function test(name, fn)
  io.write('test ' .. name .. '...')
  fn()
  io.write('passed\n')
end

test('coord equality', function()
  assert(dirtle.Coord.new(0, 0, 0):equals(dirtle.Coord.new(0, 0, 0)))
  assert(not dirtle.Coord.new(0, 0, 0):equals(dirtle.Coord.new(0, 1, 0)))
end)

test('coord addition', function()
  local c1 = dirtle.Coord.new(3, 8, -3)
  local c2 = dirtle.Coord.new(4, -1, -1)
  local sum = c1:plus(c2)
  assert(sum:equals(dirtle.Coord.new(7, 7, -4)))
end)

test('coord subtraction', function()
  local c1 = dirtle.Coord.new(3, 8, -3)
  local c2 = dirtle.Coord.new(4, -1, -1)
  local diff = c1:minus(c2)
  assert(diff:equals(dirtle.Coord.new(-1, 9, -2)))
end)

test('coord multiplication', function()
  local c1 = dirtle.Coord.new(3, 8, -3)
  local product = c1:mul(7)
  assert(product:equals(dirtle.Coord.new(21, 56, -21)))
end)

test('coord round', function()
  local c1 = dirtle.Coord.new(3.7, 8.1, -3)
  local rounded = c1:round()
  assert(rounded:equals(dirtle.Coord.new(4, 8, -3)))
end)

test('rectangle coord iter', function()
  local rect = dirtle.RectangleShape.new(
    dirtle.Coord.new(1, 2, 1),
    dirtle.Coord.new(3, 3, 2))
  local coords = {}
  for coord in rect:coords_iter() do
    table.insert(coords, coord)
  end
  local expected = {
    dirtle.Coord.new(1, 2, 1),
    dirtle.Coord.new(2, 2, 1),
    dirtle.Coord.new(3, 2, 1),
    dirtle.Coord.new(1, 3, 1),
    dirtle.Coord.new(2, 3, 1),
    dirtle.Coord.new(3, 3, 1),

    dirtle.Coord.new(1, 2, 2),
    dirtle.Coord.new(2, 2, 2),
    dirtle.Coord.new(3, 2, 2),
    dirtle.Coord.new(1, 3, 2),
    dirtle.Coord.new(2, 3, 2),
    dirtle.Coord.new(3, 3, 2),
  }

  for i, c1 in pairs(expected) do
    local found = false
    for j, c2 in pairs(coords) do
      if c1:equals(c2) then
        found = true
        break
      end
    end
    assert(found)
  end
end)

test('rectangle contains all its coords', function()
  local rect = dirtle.RectangleShape.new(
    dirtle.Coord.new(1, 2, 1),
    dirtle.Coord.new(3, 3, 2))
  local expected = {
    dirtle.Coord.new(1, 2, 1),
    dirtle.Coord.new(2, 2, 1),
    dirtle.Coord.new(3, 2, 1),
    dirtle.Coord.new(1, 3, 1),
    dirtle.Coord.new(2, 3, 1),
    dirtle.Coord.new(3, 3, 1),

    dirtle.Coord.new(1, 2, 2),
    dirtle.Coord.new(2, 2, 2),
    dirtle.Coord.new(3, 2, 2),
    dirtle.Coord.new(1, 3, 2),
    dirtle.Coord.new(2, 3, 2),
    dirtle.Coord.new(3, 3, 2),
  }

  for i, c1 in pairs(expected) do
    assert(rect:contains(c1))
  end
end)

test('rectangle does not contain external coords', function()
  local rect = dirtle.RectangleShape.new(
    dirtle.Coord.new(1, 2, 1),
    dirtle.Coord.new(3, 3, 2))
  assert(not rect:contains(dirtle.Coord.new(3, 3, 3)))
  assert(not rect:contains(dirtle.Coord.new(3, 4, 2)))
  assert(not rect:contains(dirtle.Coord.new(1, 1, 1)))
end)

test('cylinder-4 contains', function()
  local cylinder = dirtle.CylinderShape.new(dirtle.Coord.new(0, 0, 0), 4, 1)
  local s = ''
  for x = -5, 5 do
    for y = -5, 5 do
      if cylinder:contains(dirtle.Coord.new(x, y, 0)) then
        s = s .. 'x'
      else
        s = s .. ' '
      end
    end
    s = s .. '\n'
  end
  local expected = [[   xxxxx   
  xxxxxxx  
 xxxxxxxxx 
 xxxxxxxxx 
 xxxxxxxxx 
 xxxxxxxxx 
 xxxxxxxxx 
  xxxxxxx  
   xxxxx   
]]
  function trim(str)
    return str:gsub('^%s*(.-)%s*$', '%1')
  end
  assert(trim(s) == trim(expected))
end)

test('cylinder-4 coords', function()
  local cylinder = dirtle.CylinderShape.new(dirtle.Coord.new(0, 0, 0), 4, 1)
  local expected = 0
  for x = -5, 5 do
    for y = -5, 5 do
      if cylinder:contains(dirtle.Coord.new(x, y, 0)) then
        expected = expected + 1
      end
    end
  end
  local actual = 0
  for c in cylinder:coords_iter() do
    actual = actual + 1
    assert(cylinder:contains(c))
  end
  assert(actual == expected)
end)

test('intersect two rectangles', function()
  local rect1 = dirtle.RectangleShape.new(
    dirtle.Coord.new(0, 0, 0),
    dirtle.Coord.new(2, 2, 2))
  local rect2 = dirtle.RectangleShape.new(
    dirtle.Coord.new(-1, 1, 0),
    dirtle.Coord.new(2, 2, 3))
  local inter = rect1:intersect(rect2)
  local expected = dirtle.RectangleShape.new(
    dirtle.Coord.new(0, 1, 0),
    dirtle.Coord.new(2, 2, 2))

  local expectedCount = 0
  local actualCount = 0
  for c in expected:coords_iter() do
    expectedCount = expectedCount + 1
    assert(inter:contains(c))
  end
  for c in inter:coords_iter() do
    actualCount = actualCount + 1
    assert(expected:contains(c))
  end
  assert(actualCount == expectedCount)
end)

test('union two rectangles', function()
  local rect1 = dirtle.RectangleShape.new(
    dirtle.Coord.new(0, 0, 0),
    dirtle.Coord.new(2, 2, 2))
  local rect2 = dirtle.RectangleShape.new(
    dirtle.Coord.new(-1, 1, 0),
    dirtle.Coord.new(2, 2, 3))
  local union = rect1:union(rect2)
  local expectedCount = 0
  local actualCount = 0
  for c in rect1:coords_iter() do
    expectedCount = expectedCount + 1
    assert(union:contains(c))
  end
  for c in rect2:coords_iter() do
    if not rect1:contains(c) then
      expectedCount = expectedCount + 1
    end
    assert(union:contains(c))
  end
  for c in union:coords_iter() do
    actualCount = actualCount + 1
    assert(rect1:contains(c) or rect2:contains(c))
  end
  assert(actualCount == expectedCount, string.format('expected: %d actual: %d', expectedCount, actualCount))
end)

test('union circle and rod', function()
  local rect1 = dirtle.RectangleShape.new(
    dirtle.Coord.new(0, 0, 0),
    dirtle.Coord.new(2, 2, 2))
  local rect2 = dirtle.RectangleShape.new(
    dirtle.Coord.new(-1, 1, 0),
    dirtle.Coord.new(2, 2, 3))
  local union = rect1:union(rect2)
  local expectedCount = 0
  local actualCount = 0
  for c in rect1:coords_iter() do
    expectedCount = expectedCount + 1
    assert(union:contains(c))
  end
  for c in rect2:coords_iter() do
    if not rect1:contains(c) then
      expectedCount = expectedCount + 1
    end
    assert(union:contains(c))
  end
  for c in union:coords_iter() do
    actualCount = actualCount + 1
    assert(rect1:contains(c) or rect2:contains(c))
  end
  assert(actualCount == expectedCount, string.format('expected: %d actual: %d', expectedCount, actualCount))
end)

test('sphere contents', function()
  local sphere = dirtle.SphereShape.new(dirtle.Coord.new(0, 0, 0), 1)
  for c in sphere:coords_iter() do
    assert(sphere:contains(c))
    assert(-1 <= c.x)
    assert(-1 <= c.y)
    assert(-1 <= c.z)
    assert(1 >= c.x)
    assert(1 >= c.y)
    assert(1 >= c.z)
  end
end)

test('coord distance', function()
  local p1 = dirtle.Coord.new(4, 1, 7)
  local p2 = dirtle.Coord.new(6, 12, 1)
  assert(math.abs(p1:distance(p2) - 12.6886) <= 0.01)
  assert(math.abs(p2:distance(p1) - 12.6886) <= 0.01)
  assert(p1:distance(p2) >= 0)
  assert(p2:distance(p1) >= 0)
end)

test('torus contents', function()
  local origin = dirtle.Coord.new(0, 0, 0)
  local torus = dirtle.TorusShape.new(origin, 20, 8)
  plot(dirtle.TorusShape.new(dirtle.Coord.new(0, 0, 0.5), 5.5, 0.5))
  local i = 0
  assert(torus:contains(dirtle.Coord.new(0, 20, 0)))
  assert(torus:contains(dirtle.Coord.new(0, 28, 0)))
  assert(torus:contains(dirtle.Coord.new(0, 20, 8)))
  for c in torus:coords_iter() do
    i = i + 1
    assert(torus:contains(c))
    assert(-28 <= c.x)
    assert(-28 <= c.y)
    assert(-8 <= c.z)
    assert(28 >= c.x)
    assert(28 >= c.y)
    assert(8 >= c.z)
  end
  -- Sanity checks: make sure we've got some blocks here.
  assert(i > 50)
  assert(i < 56 * 56 * 16)
  -- Area of a torus is pi r^2 * 2 pi R, where R is the major radius.
  -- Give a bit of extra volume because of inexact (pretending minor radius is slightly more than
  -- half a block larger). The exact value used was determined experimentally.
  assert(i >= math.ceil(2 * math.pi * 20 * math.pi * 64))
  assert(i <= math.ceil(2 * math.pi * 20 * math.pi * 72.5))
end)
