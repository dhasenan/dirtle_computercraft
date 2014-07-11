-- Usage:
-- * Plant your turtle at the right front corner of
--   where you want your new platform. It can be above
--   it by any number of blocks.
-- * Fill your turtle's first slot with torches.
-- * Fill the other slots with blocks.
-- * Run: platform $HEIGHT, where $HEIGHT is how much higher
--   your turtle is than the platform to create.
-- The platform will be sized according to the maximum
-- square that can be made with the blocks provided.
-- Alternatively, provide forwards and left as arguments.
--
-- The turtle will round-robin through its inventory, so you
-- can make a checkered pattern without a huge amount of
-- trouble. It will place down torches evenly to cover the area.
args = {...}
height = args[1]


function returnFromSpace(x, y)
  turtle.up()
  turtle.up()
  -- Usually we finish without errors, on the first column
  -- of an empty row. That's column 1. So this should just
  -- turn left then right.
  turtle.turnLeft()
  for i=1,y-1 do
    turtle.forward()
  end
  turtle.turnRight()
  for i=1,x+2 do
    turtle.forward()
  end
  turtle.turnLeft()
  turtle.turnLeft()
  turtle.down()
  turtle.down()
  for i=1,height do
    turtle.up()
  end
  print("Turtle is taking a nap now")
end


forward = 0
left = 0
tall = 1
if table.getn(args) >= 3 then
  forward = args[2]
  left = args[3]
  if table.getn(args) >= 4 then
    tall = args[4]
  end
else
  blocks = 0
  for i=2,16 do
    blocks = blocks + turtle.getItemCount(i)
  end
  size = math.floor(math.sqrt(blocks))
  forward = size
  left = size
end

function platform(forward, left)
  numTorches = turtle.getItemCount(1)
  torchSpacing = math.ceil(forward * left / numTorches)
  torchSpacing = math.max(torchSpacing, 8)

  sinceTorch = 100
  for x=1,forward do
    for y=1,left do
      for z=1,tall do
        selected = turtle.getSelectedSlot()

        -- Select the next nonempty stack.
        for s=1,16 do
          selected = selected + 1
          if selected >= 17 then
            selected = 2
          end
          if turtle.getItemCount(selected) > 0 then
            turtle.select(selected)
            break
          end
        end
        if turtle.getItemCount(selected) == 0 then
          print("Turtle ran out of items, returning")
          returnFromSpace(x, y)
          return
        end

        -- Put down a block.
        turtle.place()

        if z < tall then
          turtle.down()
        else
          for z1=2,tall do
            turtle.up()
          end
        end
      end


      -- Is it time to put down a torch?
      if sinceTorch >= torchSpacing then
        print(string.format("placing torch at %d,%d", x, y))
        turtle.up()
        turtle.select(1)
        turtle.place()
        turtle.down()
        turtle.select(selected)
        sinceTorch = 0
      else
        sinceTorch = sinceTorch + 1
      end

      -- Move to the next pillar.
      turtle.turnRight()
      turtle.forward()
      turtle.turnLeft()
    end

    -- Go to the start of the next row.
    turtle.back()
    turtle.turnLeft()
    for i=1,left do
      turtle.forward()
    end
    turtle.turnRight()
  end
  returnFromSpace(forward, 1)
end

turtle.forward()
turtle.forward()
turtle.turnLeft()
turtle.turnLeft()
for i=1,height do
  turtle.down()
end
platform(forward, left)
