os.loadAPI('dirtle')

function usage()
  print('usage: block SIZE [LOCATION] [--hollow] [--notorch]')
  print('SIZE is LxWxH; LOCATION is X,Y,Z relative to turtle')
end

args = {...}
function optparse()
  local opts = {
    torch = true,
    hollow = false,
    start = dirtle.coord(0, 0, 0),
    finish = dirtle.coord(0, 0, 0)
  }
  local loc = dirtle.coord(0, 0, 0)
  -- Bit of a hack to use this for a size
  local size = dirtle.coord(1, 1, 1)
  local pos = 0
  for i=1, #args do
    local arg = args[i]
    if arg == '--notorch' then
      opts.torch = false
    elseif arg == '--hollow' then
      opts.hollow = true
    elseif pos == 0 then
      local c1 = strfind(arg, ',')
      local c2 = strfind(arg, ',', c1 + 1)
      local x = tonumber(strsub(arg, 1, c1 - 1))
      local y = tonumber(strsub(arg, c1 + 1, c2 - 1))
      local z = tonumber(strsub(arg, c2 + 1))
      size = dirtle.coord(x, y, z)
      pos = pos + 1
    elseif pos == 1 then
      local c1 = strfind(arg, 'x')
      local c2 = strfind(arg, 'x', c1 + 1)
      local x = tonumber(strsub(arg, 1, c1 - 1))
      local y = tonumber(strsub(arg, c1 + 1, c2 - 1))
      local z = tonumber(strsub(arg, c2 + 1))
      loc = dirtle.coord(x, y, z)
      pos = pos + 1
    end
  end
  local finish = loc:plus(size)
  -- Reorder coordinates in the most sensible fashion.
  opts.start, opts.finish = normalizeCoordRange(start, finish)
  opts.size = opts.finish:minus(opts.start)
  return opts
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
  local s2 = dirtle.Coord:new(0, 0, 0)
  local f2 = dirtle.Coord:new(0, 0, 0)
  s2.x = math.min(start.x, finish.x)
  s2.y = math.min(start.y, finish.y)
  s2.z = math.min(start.z, finish.z)
  f2.x = math.max(start.x, finish.x)
  f2.y = math.max(start.y, finish.y)
  f2.z = math.max(start.z, finish.z)
  return s2, f2
end

function buildSolidBlock(start, finish, torch)
  start, finish = normalizeCoordRange(start, finish)
  local size = finish:minus(start)
  turtle.select(1)
  dirtle.goTo(opts.start:plus(dirtle.UP))
  local l = size.x
  local w = size.y
  local h = size.z
  local block = 0
  for x=1, l do
    for y=1, w do
      for z=1, h do
        dirtle.goTo(dirtle.coord(x, y, z + 1))
        if not nextItem() then
          -- So as not to strain the pathfinding much, first go up above the project.
          -- Then head home.
          dirtle.goTo(dirtle.coord(x, y, h + 1))
          dirtle.goTo(dirtle.coord(0, 0, 0))
        end
        dirtle.placeDown()
        block = block + 1
        if z == h then
          if torch and math.fmod(block, 11) == 0 then
            dirtle.up()
            local s = turtle.getSelectedSlot()
            turtle.select(1)
            turtle.placeDown()
            turtle.select(s)
          end
        else
          dirtle.up()
        end
      end
    end
  end
end

function buildHollowBlock(start, finish, torch)
  start, finish = normalizeCoordRange(start, finish)
  -- Build the lower platform. Leave the margin alone -- don't want a possible torch in the way
  -- of the side walls.
  buildSolidBlock(
    dirtle.Coord:new(start.x + 1, start.y + 1, start.z),
    dirtle.Coord:new(finish.x - 1, finish.y - 1, start.z),
    torch)
  -- Same for the top
  buildSolidBlock(
    dirtle.Coord:new(start.x + 1, start.y + 1, finish.z),
    dirtle.Coord:new(finish.x - 1, finish.y - 1, finish.z),
    torch)

  -- Now build the left and right walls
  buildSolidBlock(
    dirtle.Coord:new(start.x, start.y, start.z),
    dirtle.Coord:new(start.x, finish.y, finish.z),
    torch)
  buildSolidBlock(
    dirtle.Coord:new(finish.x, start.y, start.z),
    dirtle.Coord:new(finish.x, finish.y, finish.z),
    torch)

  -- Now the front and back. Here, the corners have already been filled.
  -- So we have to be careful not to fill those spaces.
  buildSolidBlock(
    dirtle.Coord:new(start.x + 1, start.y, start.z),
    dirtle.Coord:new(finish.x - 1, start.y, finish.z),
    torch)
  buildSolidBlock(
    dirtle.Coord:new(start.x + 1, finish.y, start.z),
    dirtle.Coord:new(finish.x - 1, finish.y, finish.z),
    torch)
end
