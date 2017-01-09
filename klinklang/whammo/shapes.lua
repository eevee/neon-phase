local Class = require 'vendor.hump.class'
local Vector = require 'vendor.hump.vector'

local util = require 'klinklang.util'

-- Smallest unit of distance, in pixels.  Movement is capped to a multiple of
-- this, and any surfaces closer than this distance are considered touching.
-- Should be exactly representable as a float (i.e., a power of two) else
-- you're kinda defeating the point.
local QUANTUM = 1 / 8
-- Allowed rounding error when comparing whether two shapes are overlapping.
-- If they overlap by only this amount, they'll be considered touching.
local PRECISION = 1e-8

local function round_movement_to_quantum(v)
    if v.x < 0 then
        v.x = math.ceil(v.x / QUANTUM) * QUANTUM
    else
        v.x = math.floor(v.x / QUANTUM) * QUANTUM
    end
    if v.y < 0 then
        v.y = math.ceil(v.y / QUANTUM) * QUANTUM
    else
        v.y = math.floor(v.y / QUANTUM) * QUANTUM
    end
end

local Segment = Class{}

function Segment:init(x0, y0, x1, y1)
    self.x0 = x0
    self.y0 = y0
    self.x1 = x1
    self.y1 = y1
end

function Segment:__tostring()
    return ("<Segment: %f, %f to %f, %f>"):format(
        self.x0, self.y0, self.x1, self.y1)
end

function Segment:point0()
    return Vector(self.x0, self.y0)
end

function Segment:point1()
    return Vector(self.x1, self.y1)
end

function Segment:tovector()
    return Vector(self.x1 - self.x0, self.y1 - self.y0)
end

-- Returns the "outwards" normal as a Vector, assuming the points are given
-- clockwise
function Segment:normal()
    return Vector(self.y1 - self.y0, -(self.x1 - self.x0))
end

function Segment:move(dx, dy)
    self.x0 = self.x0 + dx
    self.x1 = self.x1 + dx
    self.y0 = self.y0 + dy
    self.y1 = self.y1 + dy
end




local Shape = Class{}

function Shape:init()
    self.blockmaps = setmetatable({}, {__mode = 'k'})
end

function Shape:remember_blockmap(blockmap)
    self.blockmaps[blockmap] = true
end

function Shape:forget_blockmap(blockmap)
    self.blockmaps[blockmap] = nil
end

function Shape:update_blockmaps()
    for blockmap in pairs(self.blockmaps) do
        blockmap:update(self)
    end
end

-- Extend a bbox along a movement vector (to enclose all space it might cross
-- along the way)
function Shape:extended_bbox(dx, dy)
    local x0, y0, x1, y1 = self:bbox()

    dx = dx or 0
    dy = dy or 0
    if dx < 0 then
        x0 = x0 + dx
    elseif dx > 0 then
        x1 = x1 + dx
    end
    if dy < 0 then
        y0 = y0 + dy
    elseif dy > 0 then
        y1 = y1 + dy
    end

    return x0, y0, x1, y1
end

-- An arbitrary (CONVEX) polygon
local Polygon = Class{
    __includes = Shape,
}

function Polygon:init(...)
    Shape.init(self)
    self.edges = {}
    local coords = {...}
    self.coords = coords
    self.x0 = coords[1]
    self.y0 = coords[2]
    self.x1 = coords[1]
    self.y1 = coords[2]
    for n = 1, #coords - 2, 2 do
        table.insert(self.edges, Segment(unpack(coords, n, n + 4)))
        if coords[n + 2] < self.x0 then
            self.x0 = coords[n + 2]
        end
        if coords[n + 2] > self.x1 then
            self.x1 = coords[n + 2]
        end
        if coords[n + 3] < self.y0 then
            self.y0 = coords[n + 3]
        end
        if coords[n + 3] > self.y1 then
            self.y1 = coords[n + 3]
        end
    end
    table.insert(self.edges, Segment(coords[#coords - 1], coords[#coords], coords[1], coords[2]))
    self:_generate_normals()
end

function Polygon:clone()
    -- TODO this shouldn't need to recompute all its segments
    return Polygon(unpack(self.coords))
end

function Polygon:_generate_normals()
    self._normals = {}
    for _, edge in ipairs(self.edges) do
        local normal = edge:normal()
        if normal ~= Vector.zero then
            -- What a mouthful
            self._normals[normal] = normal:normalized()
        end
    end
end

function Polygon:bbox()
    return self.x0, self.y0, self.x1, self.y1
end

function Polygon:move(dx, dy)
    self.x0 = self.x0 + dx
    self.x1 = self.x1 + dx
    self.y0 = self.y0 + dy
    self.y1 = self.y1 + dy
    for n = 1, #self.coords, 2 do
        self.coords[n] = self.coords[n] + dx
        self.coords[n + 1] = self.coords[n + 1] + dy
    end
    for _, edge in ipairs(self.edges) do
        edge:move(dx, dy)
    end
    self:update_blockmaps()
end

function Polygon:move_to(x, y)
    -- TODO
    error("TODO")
end

function Polygon:center()
    -- TODO uhh
    return self.x0 + self.width / 2, self.y0 + self.height / 2
end

function Polygon:draw(mode)
    love.graphics.polygon(mode, self.coords)
end

function Polygon:normals()
    return self._normals
end

function Polygon:project_onto_axis(axis)
    -- TODO maybe use vector-light here
    local minpt = Vector(self.coords[1], self.coords[2])
    local maxpt = minpt
    local min = axis * minpt
    local max = min
    for i = 3, #self.coords, 2 do
        local pt = Vector(self.coords[i], self.coords[i + 1])
        local dot = axis * pt
        if dot < min then
            min = dot
            minpt = pt
        elseif dot > max then
            max = dot
            maxpt = pt
        end
    end
    return min, max, minpt, maxpt
end

function Polygon:slide_towards(other, movement)
    -- TODO skip entirely if bbox movement renders this impossible
    -- Use the separating axis theorem.
    -- 1. Choose a bunch of axes, generally normals of the shapes.
    -- 2. Project both shapes along each axis.
    -- 3. If the projects overlap along ANY axis, the shapes overlap.
    --    Otherwise, they don't.
    -- This code also does a couple other things.
    -- b. It uses the direction of movement as an extra axis, in order to find
    --    the minimum possible movement between the two shapes.
    -- a. It keeps values around in terms of their original vectors, rather
    --    than lengths or normalized vectors, to avoid precision loss
    --    from taking square roots.

    -- Mapping of normal vectors (i.e. projection axes) to their normalized
    -- versions (needed for comparing the results of the projection)
    local movenormal = movement:perpendicular()
    local axes = {}
    if movenormal ~= Vector.zero then
        axes[movenormal] = movenormal:normalized()
    end
    for norm, norm1 in pairs(self:normals()) do
        axes[norm] = norm1
    end
    for norm, norm1 in pairs(other:normals()) do
        axes[norm] = norm1
    end

    -- Project both shapes onto each axis and look for the minimum distance
    local maxdist = -math.huge
    local maxsep, maxdir
    -- TODO i would love to get rid of ClockRange, and it starts right here; i
    -- think at most we can return a span of two normals, if you hit a corner
    local clock = util.ClockRange()
    --print("us:", self:bbox())
    --print("them:", other:bbox())
    for fullaxis, axis in pairs(axes) do
        local is_move_axis = fullaxis == movenormal
        local min1, max1, minpt1, maxpt1 = self:project_onto_axis(axis)
        local min2, max2, minpt2, maxpt2 = other:project_onto_axis(axis)
        local dist, sep
        if min1 < min2 then
            -- 1 appears first, so take the distance from 1 to 2
            dist = min2 - max1
            sep = minpt2 - maxpt1
        else
            -- Other way around
            dist = min1 - max2
            -- Note that sep is always the vector from us to them
            sep = maxpt2 - minpt1
            -- Likewise, flip the axis so it points towards them
            fullaxis = -fullaxis
        end
        -- Critically, don't round /up/ from a negative value of less than one
        -- quantum, because that could make us ignore a non-trivial overlap.
        -- round_to_quantum is only appropriate for the movement vector!
        if -PRECISION < dist and dist < QUANTUM then
            dist = 0
        end
        --print("    axis:", fullaxis, "dist:", dist, "sep:", sep)
        if dist >= 0 then
            -- The movement itself may be away from the other shape, in which
            -- case we can stop here; we know they'll never collide
            if fullaxis * movement <= 0 and dist > 0 then
                return
            end

            -- If the distance isn't negative, then it's possible to do a slide
            -- anywhere in the general direction of this axis
            local perp = fullaxis:perpendicular()
            clock:union(perp, -perp)
        end
        if dist > maxdist then
            maxdist = dist
            maxsep = sep
            maxdir = fullaxis
        end
    end

    if maxdist < 0 then
        -- Shapes are already colliding
        -- TODO should maybe...  return something more specific here?
        --error("seem to be inside something!!  stopping so you can debug buddy  <3")
        --print("ALREADY COLLIDING", worldscene.collider:get_owner(other))
        return Vector.zero, -1, util.ClockRange(util.ClockRange.ZERO, util.ClockRange.ZERO)
        --return
    end

    local gap = maxsep:projectOn(maxdir)
    local allowed = movement:projectOn(maxdir)
    --print("  max dist:", maxdist, "in dir:", maxdir, "  gap:", gap, "allowed:", allowed)
    -- If we're already moving in an allowed slide direction, then we can't
    -- possibly collide
    if clock:includes(movement) then
        -- One question remains: will we actually touch?
        -- TODO i'm not totally confident in this logic; seems like near misses
        -- without touches might not be handled correctly...?
        if gap:len2() <= allowed:len2() then
            -- This is a slide; we will touch (or are already touching) the
            -- other object, but can continue past it
            return movement, 0, clock
        else
            -- We'll never touch
            return
        end
    end

    local mv
    if math.abs(allowed.x) > math.abs(allowed.y) then
        mv = movement * gap.x / allowed.x
    else
        mv = movement * gap.y / allowed.y
    end
    round_movement_to_quantum(mv)
    local move_len2 = mv:len2()
    --if move_len2 < 0 or move_len2 > movement:len2() then
    if move_len2 > movement:len2() then
        -- Won't actually hit!
        return
    end

    return mv, 1, clock
end

-- An AABB, i.e., an unrotated rectangle
local _XAXIS = Vector(1, 0)
local _YAXIS = Vector(0, 1)
local Box = Class{
    __includes = Polygon,
    -- Handily, an AABB only has two normals: the x and y axes
    _normals = { [_XAXIS] = _XAXIS, [_YAXIS] = _YAXIS },
}

function Box:init(x, y, width, height)
    Polygon.init(self, x, y, x + width, y, x + width, y + height, x, y + height)
    self.width = width
    self.height = height
end

function Box:clone()
    return Box(self.x0, self.y0, self.width, self.height)
end

function Box:_generate_normals()
end

function Box:move_to(x, y)
    self:move(x - self.x0, y - self.y0)
    self:update_blockmaps()
end

function Box:center()
    return self.x0 + self.width / 2, self.y0 + self.height / 2
end

return {
    Box = Box,
    Polygon = Polygon,
    Segment = Segment,
}
