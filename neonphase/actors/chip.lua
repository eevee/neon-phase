local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local actors_misc = require 'klinklang.actors.misc'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'


local ChipLaser = actors_base.MobileActor:extend{
    name = "chip's laser",
    sprite_name = "chip's laser",

    gravity_multiplier = 0,
    ground_friction = 0,
    constant_velocity = 512,
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
        local obstacle = worldscene.collider:get_owner(shape)
        if touchtype > 0 and obstacle ~= self.ptrs.owner and obstacle ~= self.ptrs.owner.ptrs.owner then
            if obstacle then
                obstacle:damage(self, 10)
            end
            self.velocity = Vector(0, 0)
            self.sprite:set_pose('hit')
            worldscene.fluct:to(self, 0.25, {}):oncomplete(function() 
                worldscene:remove_actor(self)
            end)
            return
        end
    end
end

-- Chip is immune to physics
-- FIXME i do wonder if physics should be a flag (component?!) rather than
-- an inheritance level
local Chip = actors_base.Actor:extend{
    name = 'chip',
    sprite_name = 'chip',

    owner_offset = Vector(-16, -24),
    max_scalar_acceleration = 512,
    scalar_velocity = 0,
    has_laser = false,
    can_fire = true,
    owner_gliding_offset = Vector(0, -24),

    decision_fire = false,

    -- Goal-seeking, which sounds fancier than it is; Chip can fly to a point
    -- and then do something
    goal = nil,  -- Target position, possibly relative to an actor
    goal_callback = nil,  -- What to do once there
    -- Also, ptrs.goal is sometimes used as the actor being flown towards, if any

    -- Carrying objects or the player
    cargo = nil,  -- Strong reference to the object, since we own it
    cargo_in_world = nil,  -- Whether we left the object in-world (player)
    cargo_anchor = nil,  -- Carrying point on the object, relative to its pos
    cargo_offset = Vector(0, 8),  -- Distance between our pos and the cargo anchor

    overlay_sprite = nil,
}

function Chip:init(owner, ...)
    actors_base.Actor.init(self, ...)

    self.velocity = Vector(0, 0)
    self.ptrs.owner = owner
end

function Chip:decide_fire(decision)
    self.decision_fire = decision
end

function Chip:update(dt)
    if self.decision_fire and self.has_laser and self.can_fire then
        worldscene:add_actor(ChipLaser(self, self.pos + Vector(0, -8)))
        self.can_fire = false
        worldscene.tick:delay(function() self.can_fire = true end, 0.25)
    end

    if self.goal then
        -- Moving towards some particular point
        local goal = self.goal
        if self.ptrs.goal then
            goal = goal + self.ptrs.goal.pos
        end
        local reached = self:_move_towards(goal, dt)
        if reached then
            self.goal_callback(self)
            self:_clear_goal()
        end
    elseif self.cargo == self.ptrs.owner then
        -- Carrying the player; update our position accordingly
        self.pos = self.cargo.pos - self.cargo_offset + self.cargo_anchor
    elseif self.ptrs.owner then
        -- Following the player, and possibly carrying something else
        local offset = self.owner_offset
        if self.ptrs.owner.facing_left then
            offset = Vector(-offset.x, offset.y)
        end

        local goal = self.ptrs.owner.pos + offset + Vector(0, math.sin(self.timer) * 8)
        local reached = self:_move_towards(goal, dt)

        if reached then
            self.sprite:set_facing_right(not self.ptrs.owner.facing_left)
        end
    end

    if self.cargo and self.cargo ~= self.ptrs.owner then
        -- FIXME this is wrong since the velocity might be purely vertical
        local lag_offset = self.scalar_velocity / 60
        -- FIXME ehh
        if self.sprite.facing == 'right' then
            lag_offset = -lag_offset
        end
        self.cargo.pos = self.pos + self.cargo_offset - self.cargo_anchor + Vector(lag_offset, 0)
    end

    actors_base.Actor.update(self, dt)

    if self.overlay_sprite then
        self.overlay_sprite:update(dt)
    end
end

function Chip:_move_towards(goal, dt)
    local separation = goal - self.pos
    local distance = separation:len()

    if distance >= 1 then
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
        self.pos.x = math.floor(self.pos.x + 0.5)
        self.pos.y = math.floor(self.pos.y + 0.5)
        if math.abs(separation.x) > 1 then
            self.sprite:set_facing_right(separation.x > 0)
        end
        return false
    else
        self.scalar_velocity = 0
        return true
    end
end

function Chip:draw()
    actors_base.Actor.draw(self)

    if self.cargo then
        if self.cargo ~= self.ptrs.owner then
            self.cargo:draw()
        end
        self.overlay_sprite:draw_at(self.pos + Vector(0, 4))
    end
end


-- API

-- Tell Chip to approach a point.
-- If actor is nil, the point is in absolute coordinates, and the approach
-- cannot be cancelled.
-- If actor is not nil, the point is relative to the actor's position, and Chip
-- will chase the actor as it moves.  The actor can be passed to
-- cancel_approach() to abandon the chase.
function Chip:approach(actor, point, callback)
    if self.goal then
        return
    end

    self.goal = point or Vector.zero
    self.goal_callback = callback
    self.ptrs.goal = actor
end

-- If Chip is currently moving towards the given actor, stop
function Chip:cancel_approach(actor)
    if self.ptrs.goal == actor then
        self:_clear_goal()
    end
end

function Chip:_clear_goal()
    self.goal = nil
    self.goal_callback = nil
    self.ptrs.goal = nil
end

-- Ask Chip to move towards something and pick it up
function Chip:pick_up(actor, callback)
    if self.cargo then
        return
    end
    if self.goal then
        return
    end

    -- Hold objects by the top center of their sprite
    -- TODO as usual, this might change if the sprite changes, and it might be
    -- better to specify this explicitly anyway
    if actor.sprite then
        -- FIXME oh lol wait this is positioned, i want the original offset
        local x0, y0, x1, y1 = actor.sprite.shape:bbox()
        self.cargo_anchor = Vector(math.floor((x0 + x1) / 2), y0)
    else
        self.cargo_anchor = Vector.zero
    end

    self:approach(
        actor,
        self.cargo_anchor - self.cargo_offset,
        function()
            self.cargo = actor

            -- If we're carrying the player, we should leave them in the world and
            -- follow their movement, rather than vice versa
            self.cargo_in_world = actor == self.ptrs.owner
            if not self.cargo_in_world then
                worldscene:remove_actor(actor)
            end

            self.overlay_sprite = game.sprites["chip's tractor beam"]:instantiate()

            if callback then
                callback()
            end
        end)
end

-- Ask Chip to drop its current cargo at some point.  Note that this cannot be
-- cancelled.
function Chip:set_down(point, callback)
    if not self.cargo then
        return
    end

    self:approach(
        nil,
        point - self.cargo_offset + self.cargo_anchor,
        function()
            local cargo = self.cargo
            cargo.pos = point

            if not self.cargo_in_world then
                worldscene:add_actor(self.cargo)
            end

            self.cargo = nil
            self.cargo_in_world = nil
            self.cargo_anchor = nil
            self.overlay_sprite = nil

            if callback then
                callback(cargo)
            end
        end)
end


local UpgradeChip = actors_base.Actor:extend{
    name = 'upgrade chip',
    sprite_name = 'upgrade chip',
}

function UpgradeChip:on_collide(other, direction)
    if other.is_player then
        -- TODO what if not chip?
        other.ptrs.chip.has_laser = true
        worldscene:remove_actor(self)
    end
end


return Chip
