# Dirtle, the dead reckoning turtle

A ComputerCraft script for building shapes.

This is pretty much abandoned at the moment, but someone might find it interesting.

The primary script is `dirtle.lua`. This defines the dead reckoning navigation and shape building.

## Shapes

The basic predefined shapes are:

* RectangleShape: a rectangular prism. A generalization of a cube.
* CylinderShape: a cylinder.
* TorusShape: donuts. (Only supports round ones. No toroidal lozenges or anything.)
* SphereShape: spheres. Balls. (Only supports round ones. No ovoids.)

## Combining and altering shapes

There are a few ways to combine or alter shapes. They all produce new shapes; once a shape is
created, it's immutable.

### shape:union(other)

This produces a new shape that incorporates both shapes. For instance, this produces a dome on top
of a rectangular prism:

    local sphere = SphereShape.new(Coord.new(0, 10, 0), 5)
    local base = RectangleShape.new(
        Coord.new(-5, 0, -5),
        Coord.new(5, 10, 5))
    local shape = sphere:union(base)

### shape:intersect(other)

This produces a new shape that only contains points in common between its two shapes. For instance,
this produces a rectangular rod with rounded edges:

    local sphere = SphereShape.new(Coord.new(0, 10, 0), 10)
    local prism = RectangleShape.new(
        Coord.new(-10, -3, -5),
        Coord.new(10, 3, 5))
    local rounded_prism = sphere:intersect(prism)

### shape:minus(other)

This produces a new shape that contains everything in the first shape that isn't in the second. For
instance, this produces a sphere with a tunnel through it:

    local sphere = SphereShape.new(Coord.new(0, 10, 0), 10)
    local prism = RectangleShape.new(
        Coord.new(-10, -3, -5),
        Coord.new(10, 3, 5))
    local rounded_prism = sphere:minus(prism)

### shape:xor(other)

This produces a new shape that contains all points in exactly one of the input shapes. For instance,
this produces a sphere with a tunnel in it, with a rod extending out from where the tunnel starts to
either side of the sphere:

    local sphere = SphereShape.new(Coord.new(0, 10, 0), 10)
    local prism = RectangleShape.new(
        Coord.new(-10, -3, -5),
        Coord.new(10, 3, 5))
    local weird_shape = sphere:xor(prism)

Not incredibly useful, but it amused me to add it.

### shape:translate(coord)

This moves shapes around. Generally, you could simply make your shapes in the correct position to
begin with, but that often involves a lot of math on your end. Plus if you defined functions to
create shapes you commonly use, it might be inconvenient to modify them as appropriate.

For example:

    function eldritch_obelisk()
        -- something complex that you wrote a while ago
        return shpae
    end
    local obelisk = eldritch_obelisk()
    local left_obelisk = obelisk:translate(Coord.new(-10, 0, -10))
    local right_obelisk = obelisk:translate(Coord.new(10, 0, -10))
    local front_obelisk = obelisk:translate(Coord.new(0, 0, 10))


# Defining new shapes

To define a shape, you need three functions:

* A constructor that accepts the data needed to define the shape
* A `:contains` function that determines if a point is within the shape
* A `:coords_iter` function yielding an iterator over the points within the shape

Look at SphereShape for an example of how that works.


# Future directions

While this library is dead, here's how I'd like to evolve it:

* automatically retrieve fuel and more blocks from defined storage units
* define brushes to determine what materials to use
* automatically place torches
* apportion work among multiple turtles
* incorporate GPS instead of just using dead reckoning
* add more shapes: generalized spheres and toruses, regular polygons, etc
