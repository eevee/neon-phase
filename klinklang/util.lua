--[[
Argh!  The dreaded util module.  You know what to expect.
]]
local Vector = require 'vendor.hump.vector'

local Object = require 'klinklang.object'

--------------------------------------------------------------------------------
-- Conspicuous mathematical omissions

local function sign(n)
    if n == 0 then
        return 0
    elseif n == math.abs(n) then
        return 1
    else
        return -1
    end
end

local function clamp(n, min, max)
    if n < min then
        return min
    elseif n > max then
        return max
    else
        return n
    end
end

local function divmod(n, b)
    return math.floor(n / b), n % b
end


--------------------------------------------------------------------------------
-- Operations on ranges of angles, represented by clockwise pairs of vectors,
-- without ever calculating the actual angles.
-- Note that this is "clockwise" from the perspective of the reversed y-axis
-- used by LÖVE and most other graphics engines.  On a regular Cartesian plane,
-- everything is backwards.

-- A range of angles, represented by pairs of vectors going clockwise
local ClockRange = Object:extend{
    -- The zero angle
    ZERO = Vector(1, 0),
}

-- Returns 1 if the second vector is clockwise from the first, -1 if the second
-- vector is counterclockwise, and zero if they're parallel (or antiparallel)
function ClockRange.direction(a, b)
    -- TODO: explain why this works
    return sign(a:perpendicular() * b)
end

-- Returns true if the range [a, b] contains the angle v
function ClockRange.contains(a, b, v)
    -- If the angle swept by a and b is greater than half a circle, then it
    -- contains v if v is clockwise from a OR counter-clockwise from b.
    -- Otherwise, it contains v if v is cw from a AND ccw from b.
    local cw_from_a = ClockRange.direction(a, v) >= 0
    local ccw_from_b = ClockRange.direction(b, v) <= 0
    local wider_than_semi = ClockRange.direction(a, b) < 0
    if wider_than_semi then
        return cw_from_a or ccw_from_b
    else
        return cw_from_a and ccw_from_b
    end
end

-- Returns true if the vector is at the zero angle, along the positive x axis
function ClockRange.iszero(v)
    return v.x > 0 and v.y == 0
end

function ClockRange:init(a, b)
    self.ranges = {}

    if a then
        self:set(a, b)
    end
end

function ClockRange:__tostring()
    local guts = ""
    for _, range in ipairs(self.ranges) do
        if guts ~= "" then
            guts = guts .. ", "
        end
        guts = guts .. ("%s to %s"):format(unpack(range))
    end
    return ("<ClockRange: %s>"):format(guts)
end

function ClockRange:set(a, b)
    if ClockRange.contains(b, a, self.ZERO) then
        self.ranges = {{a, b}}
    else
        self.ranges = {{self.ZERO, b}, {a, self.ZERO}}
    end
end

function ClockRange:isempty()
    return #self.ranges == 0
end

function ClockRange:isall()
    -- TODO not actually equal to zero, just in the same direction
    return #self.ranges == 1 and self.ranges[1][1] == self.ZERO and self.ranges[1][2] == self.ZERO
end

function ClockRange:inverted()
    if self:isempty() then
        return ClockRange(self.ZERO, self.ZERO)
    elseif self:isall() then
        return ClockRange()
    end
    local new = ClockRange()
    local pending = self.ZERO
    for _, range in ipairs(self.ranges) do
        -- Ignore start if it's zero
        if not (range[1].x > 0 and range[1].y == 0) then
            table.insert(new.ranges, {pending, range[1]})
        end
        pending = range[2]
    end
    if not (pending.x > 0 and pending.y == 0) then
        table.insert(new.ranges, {pending, self.ZERO})
    end
    return new
end

function ClockRange:extremes()
    local edges = {}
    for n, range in ipairs(self.ranges) do
        for _, vec in ipairs(range) do
            -- An edge that appears twice is not actually an edge
            if edges[vec] then
                edges[vec] = nil
            else
                edges[vec] = true
            end
        end
    end
    return edges
end

-- Return the extreme that's closest in angle to the given reference vector
function ClockRange:closest_extreme(reference)
    if self:isempty() then
        return nil
    elseif self:isall() then
        return reference
    elseif self:includes(reference) then
        return reference
    end

    local ret
    local maxdot = -math.huge
    -- Dot product will tell us the closest angle, as long as we normalize each
    -- extreme first
    for vec in pairs(self:extremes()) do
        local dot = vec:normalized() * reference
        if dot > maxdot then
            ret = vec
            maxdot = dot
        end
    end
    return ret
end

function ClockRange:includes(v)
    if self:isall() then
        return true
    end
    for _, range in ipairs(self.ranges) do
        if ClockRange.contains(range[1], range[2], v) then
            return true
        end
    end
    return false
end

function ClockRange:union(other, b)
    if b ~= nil then
        other = ClockRange(other, b)
    end
    if self:isall() or other:isall() then
        self.ranges = {{ClockRange.ZERO, ClockRange.ZERO}}
    elseif self:isempty() then
        self.ranges = {unpack(other.ranges)}
    elseif other:isempty() then
        return
    else
        self:_union(other)
    end
end

local function _interleave_ranges(ranges1, ranges2)
    local n1, n2 = 0, 0
    return function()
        if n1 >= #ranges1 then
            n2 = n2 + 1
            return ranges2[n2]
        elseif n2 >= #ranges2 then
            n1 = n1 + 1
            return ranges1[n1]
        end

        local next1 = ranges1[n1 + 1][1]
        local next2 = ranges2[n2 + 1][1]
        if ClockRange.iszero(next1) then
            n1 = n1 + 1
            return ranges1[n1]
        elseif ClockRange.iszero(next2) then
            n2 = n2 + 1
            return ranges2[n2]
        elseif ClockRange.contains(ClockRange.ZERO, next1, next2) then
            n2 = n2 + 1
            return ranges2[n2]
        else
            n1 = n1 + 1
            return ranges1[n1]
        end
    end
end

function ClockRange:_union(other)
    local new_ranges = {}
    local pending
    for range in _interleave_ranges(self.ranges, other.ranges) do
        -- There are three possible cases: pending contains range, pending
        -- overlaps range, and pending is independent from range.
        -- Distinguishing them is slightly tricky because our minimum and
        -- maximum angle is the same: zero.  If pending = {0, a} and range =
        -- {b, 0}, then it looks like pending's start and range's end overlap!
        -- Avoid asking if pending[1] is in range or range[2] is in pending.
        if not pending then
            pending = {unpack(range)}
        elseif ClockRange.contains(pending[1], pending[2], range[1]) then
            -- They overlap to some extent, but who ends first?
            if ClockRange.contains(range[1], range[2], pending[2]) then
                -- New range is wider than the pending range; extend it
                pending[2] = range[2]
            end
        else
            -- If the new range doesn't overlap with the pending range, commit
            -- the pending range; the new range is now pending
            table.insert(new_ranges, pending)
            pending = {unpack(range)}
        end
        if ClockRange.iszero(pending[2]) then
            -- Once we have a pending slice that touches the end, we're done
            break
        end
    end
    if pending then
        table.insert(new_ranges, pending)
    end

    self.ranges = new_ranges
end

function ClockRange:intersect(other, b)
    if b ~= nil then
        other = ClockRange(other, b)
    end
    if self:isempty() then
        self.ranges = {unpack(other.ranges)}
    elseif other:isempty() then
        return
    else
        self:_intersect(other)
    end
end

function ClockRange:_intersect(other)
    local inv = self:inverted()
    inv:union(other:inverted())
    self.ranges = inv:inverted().ranges
end







return {
    sign = sign,
    clamp = clamp,
    divmod = divmod,
    ClockRange = ClockRange,
    vector_clock_direction = ClockRange.direction,
}
