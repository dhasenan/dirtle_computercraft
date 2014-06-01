require('dirtle')
-- os.loadAPI() loads stuff into a new namespace.
-- require() loads stuff into the global namespace.
-- This is a hack to make the API work as we want.
local dirtle = _G


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
  local sum = c1:add(c2)
  assert(sum:equals(dirtle.Coord.new(7, 7, -4)))
end)

test('coord subtraction', function()
  local c1 = dirtle.Coord.new(3, 8, -3)
  local c2 = dirtle.Coord.new(4, -1, -1)
  local diff = c1:sub(c2)
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
