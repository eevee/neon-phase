local Class = require 'vendor.hump.class'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local actors_misc = require 'klinklang.actors.misc'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'


local ChipLaser = Class{
    __includes = actors_base.MobileActor,

    shape = whammo_shapes.Box(4, 7, 8, 3),
    anchor = Vector(5, 8),
    sprite_name = "chip's laser",

    gravity_multiplier = 0,
    ground_friction = 0,
    constant_velocity = 256,
}

function ChipLaser:init(owner, ...)
    actors_base.Actor.init(self, ...)

    self.ptrs.owner = owner
    self.velocity = Vector(self.constant_velocity, 0)
    -- FIXME probably chip should pass this in
    if owner.sprite.facing == 'left' then
        self.facing_left = true
        self.sprite:set_facing_right(false)
        self.velocity.x = -self.velocity.x
    end
end

function ChipLaser:blocks()
    return false
end

function ChipLaser:update(dt)
    -- FIXME probably don't bother with this if we're already in a hit
    actors_base.MobileActor.update(self, dt)
    for shape, touchtype in pairs(self._stupid_hits_hack) do
        -- FIXME seems to be a recurring problem of having certain individual
        -- objects ignore collision with certain other individual objects;
        -- maybe the collider itself should know about this
        local owner = worldscene.collider:get_owner(shape)
        if touchtype > 0 and owner ~= self.ptrs.owner and owner ~= self.ptrs.owner.ptrs.owner then
            self.velocity = Vector(0, 0)
            self.sprite:set_pose('hit')
            worldscene.fluct:to(self, 0.25, {}):oncomplete(function() 
                worldscene:remove_actor(self)
            end)
            return
        end
    end
end

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
    can_fire = true,
}

function Chip:init(owner, ...)
    actors_base.Actor.init(self, ...)

    self.velocity = Vector(0, 0)
    self.ptrs.owner = owner
end

function Chip:update(dt)
    if self.can_fire and love.keyboard.isScancodeDown('d') then
        worldscene:add_actor(ChipLaser(self, self.pos + Vector(0, -8)))
        self.can_fire = false
        worldscene.fluct:to(self, 0.25, {}):oncomplete(function() 
            self.can_fire = true
        end)
    end

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
