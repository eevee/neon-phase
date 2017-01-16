local Vector = require 'vendor.hump.vector'

local Object = require 'klinklang.object'
local util = require 'klinklang.util'

-- Allowed rounding error when comparing whether two shapes are overlapping.
-- If they overlap by only this amount, they'll be considered touching.
local PRECISION = 1e-8


local Segment = Object:extend()

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


local Shape = Object:extend{
    xoff = 0,
    yoff = 0,
}

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

function Shape:flipx(axis)
    error("flipx not implemented")
end

function Shape:move(dx, dy)
    error("move not implemented")
end

function Shape:move_to(x, y)
    self:move(x - self.xoff, y - self.yoff)
end

function Shape:draw(mode)
    error("draw not implemented")
end

function Shape:normals()
    error("normals not implemented")
end


-- An arbitrary (CONVEX) polygon
local Polygon = Shape:extend()

-- FIXME i think this blindly assumes clockwise order
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

function Polygon:flipx(axis)
    local reverse_coords = {}
    for n = #self.coords - 1, 1, -2 do
        reverse_coords[#self.coords - n] = axis * 2 - self.coords[n]
        reverse_coords[#self.coords - n + 1] = self.coords[n + 1]
    end
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
    self.xoff = self.xoff + dx
    self.yoff = self.yoff + dy
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

    if other.subshapes then
        return self:_multi_slide_towards(other, movement)
    end

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
    local cant_collide = false
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
        -- Ignore extremely tiny overlaps, which are likely precision errors
        if math.abs(dist) < PRECISION then
            dist = 0
        end
        --print("    axis:", fullaxis, "dist:", dist, "sep:", sep)
        if dist >= 0 then
            -- The movement itself may be away from the other shape, in which
            -- case we can stop here; we know they'll never collide.
            -- (The most common case here is that fullaxis is the move normal.)
            if fullaxis * movement <= 0 then
                if dist > 0 then
                    return
                else
                    -- If dist is zero, then they might still /touch/, and we
                    -- need to know about that for other reasons
                    -- FIXME wait, do we?  where do i care about a perfect
                    -- existing slide?  if i'm sliding along the ground then
                    -- i'm not /on/ the ground...
                    cant_collide = true
                end
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
        -- FIXME should have /some/ kind of gentle rejection here
        --print("ALREADY COLLIDING", maxdist, worldscene.collider:get_owner(other))
        --error("seem to be inside something!!  stopping so you can debug buddy  <3")
        return Vector.zero, -1, util.ClockRange(util.ClockRange.ZERO, util.ClockRange.ZERO)
        --return
    end

    local gap = maxsep:projectOn(maxdir)
    if math.abs(gap.x) < PRECISION then
        gap.x = 0
    end
    if math.abs(gap.y) < PRECISION then
        gap.y = 0
    end
    local allowed = movement:projectOn(maxdir)
    --print("  max dist:", maxdist, "in dir:", maxdir, "  gap:", gap, "allowed:", allowed, "clock:", clock)
    if cant_collide then
        -- One question remains: will we actually touch?
        -- TODO i'm not totally confident in this logic; seems like near misses
        -- without touches might not be handled correctly...?
        -- TODO do we actually care about this at all?  there's a use for "what
        -- am i overlapping" but that could be done differently
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
    if allowed == Vector.zero then
        error("pretty sure this shouldn't be possible")
        mv = Vector.zero:clone()
    elseif math.abs(allowed.x) > math.abs(allowed.y) then
        mv = movement * gap.x / allowed.x
    else
        mv = movement * gap.y / allowed.y
    end
    local move_len2 = mv:len2()
    if move_len2 > movement:len2() then
        -- Won't actually hit!
        return
    end

    return mv, 1, clock, -maxdir
end

function Polygon:_multi_slide_towards(other, movement)
    local move, touchtype, clock, movelen
    for _, subshape in ipairs(other.subshapes) do
        local move2, touchtype2, clock2 = self:slide_towards(subshape, movement)
        if move2 == nil then
            -- Do nothing
        elseif move == nil then
            -- First result; just accept it
            move, touchtype, clock = move2, touchtype2, clock2
            movelen = move:len2()
        else
            -- Need to combine
            local movelen2 = move2:len2()
            if movelen2 < movelen then
                move, touchtype, clock = move2, touchtype2, clock2
                movelen = movelen2
            elseif movelen2 == movelen then
                clock:intersect(clock2)
                touchtype = math.min(touchtype, touchtype2)
            end
        end
    end

    return move, touchtype, clock
end


-- An AABB, i.e., an unrotated rectangle
local _XAXIS = Vector(1, 0)
local _YAXIS = Vector(0, 1)
local Box = Polygon:extend{
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

function Box:flipx(axis)
    return Box(axis * 2 - self.x0 - self.width, self.y0, self.width, self.height)
end

function Box:_generate_normals()
end

function Box:center()
    return self.x0 + self.width / 2, self.y0 + self.height / 2
end


local MultiShape = Shape:extend()

function MultiShape:init(...)
    MultiShape.__super.init(self)

    self.subshapes = {}
    for _, subshape in ipairs{...} do
        self:add_subshape(subshape)
    end
end

function MultiShape:add_subshape(subshape)
    -- TODO what if subshape has an offset already?
    table.insert(self.subshapes, subshape)
    self:update_blockmaps()
end

function MultiShape:clone()
    return MultiShape(unpack(self.subshapes))
end

function MultiShape:bbox()
    local x0, x1 = math.huge, -math.huge
    local y0, y1 = math.huge, -math.huge
    for _, subshape in ipairs(self.subshapes) do
        local subx0, suby0, subx1, suby1 = subshape:bbox()
        x0 = math.min(x0, subx0)
        y0 = math.min(y0, suby0)
        x1 = math.max(x1, subx1)
        y1 = math.max(y1, suby1)
    end
    return x0, y0, x1, y1
end

function MultiShape:move(dx, dy)
    self.xoff = self.xoff + dx
    self.yoff = self.yoff + dy
    for _, subshape in ipairs(self.subshapes) do
        subshape:move(dx, dy)
    end
end

function MultiShape:draw(...)
    for _, subshape in ipairs(self.subshapes) do
        subshape:draw(...)
    end
end

function MultiShape:normals()
    local normals = {}
    -- TODO maybe want to compute this only once
    for _, subshape in ipairs(self.subshapes) do
        for k, v in pairs(subshape:normals()) do
            normals[k] = v
        end
    end
    return normals
end

function MultiShape:project_onto_axis(...)
    local min, max, minpt, maxpt
    for i, subshape in ipairs(self.subshapes) do
        if i == 1 then
            min, max, minpt, maxpt = subshape:project_onto_axis(...)
        else
            local min2, max2, minpt2, maxpt2 = subshape:project_onto_axis(...)
            if min2 < min then
                min = min2
                minpt = minpt2
            end
            if max2 > max then
                max = max2
                maxpt = maxpt2
            end
        end
    end
    return min, max, minpt, maxpt
end



return {
    Box = Box,
    MultiShape = MultiShape,
    Polygon = Polygon,
    Segment = Segment,
}
