local Class = require 'vendor.hump.class'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local actors_misc = require 'klinklang.actors.misc'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'


local Chip = Class{
    -- Chip is immune to physics
    -- FIXME i do wonder if physics should be a flag (component?!) rather than
    -- an inheritance level
    __includes = actors_base.Actor,

    shape = whammo_shapes.Box(0, 0, 16, 16),
    anchor = Vector(8, 12),
    sprite_name = 'chip',

    owner_offset = Vector(-16, -24),
    max_scalar_acceleration = 512,
    scalar_velocity = 0,
}

function Chip:init(owner, ...)
    actors_base.Actor.init(self, ...)

    self.velocity = Vector(0, 0)
    self.ptrs.owner = owner
end

function Chip:update(dt)
    if self.ptrs.owner then
        local offset = self.owner_offset
        if self.ptrs.owner.facing_left then
            offset = Vector(-offset.x, offset.y)
        end

        local goal = self.ptrs.owner.pos + offset + Vector(0, math.sin(self.timer) * 8)
        local separation = goal - self.pos
        local distance = separation:len()

        -- If we're close and fast enough, we need to start decelerating so we
        -- come to a nice stop right at our goal, instead of overshooting
        local t = self.scalar_velocity / self.max_scalar_acceleration
        -- This is ½at² = ½t(v₀ + v), except we know v is zero
        local decel_distance = self.scalar_velocity * t / 2
        local accel = self.max_scalar_acceleration
        if decel_distance >= distance then
            accel = -accel
        end
        self.scalar_velocity = self.scalar_velocity + accel * dt

        self.pos = self.pos + separation / distance * self.scalar_velocity * dt

        if math.abs(separation.x) < 1 then
            self.sprite:set_facing_right(not self.ptrs.owner.facing_left)
        else
            self.sprite:set_facing_right(separation.x > 0)
        end
    end

    actors_base.Actor.update(self, dt)
end


return Chip
