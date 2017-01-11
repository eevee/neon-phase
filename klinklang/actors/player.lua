local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local actors_misc = require 'klinklang.actors.misc'
local Object = require 'klinklang.object'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'


local Player = actors_base.MobileActor:extend{
    name = 'kid neon',
    -- FIXME game-specific
    sprite_name = 'kid neon',

    is_player = true,

    inventory_cursor = 0,
}

function Player:init(...)
    actors_base.MobileActor.init(self, ...)

    -- TODO not sure how i feel about having player state attached to the
    -- actor, but it /does/ make sense, and it's certainly an improvement over
    -- a global
    -- TODO BUT either way, this needs to be initialized at the start of the
    -- game and correctly restored on map load
    self.inventory = {}
end

-- FIXME game-specific
local Chip = require 'neonphase.actors.chip'
function Player:on_enter()
    local chip
    if self.chip then
        chip = self.chip
        self.chip = nil
    else
        -- FIXME chip should spawn at their desired location
        chip = Chip(self, self.pos:clone())
    end
    self.ptrs.chip = chip
    worldscene:add_actor(chip)
end
function Player:on_leave()
    -- Keep Chip with us as a strong reference, so they can be returned to the
    -- map when we are
    self.chip = self.ptrs.chip
    worldscene:remove_actor(self.chip)
end
function Player:blocks(other, d)
    if other.sprite_name == "chip's laser" then
        return false
    end
    return true
end

function Player:update(dt)
    if self.is_dead then
        -- FIXME a corpse still has physics, just not input
        self.sprite:update(dt)
        return
    end

    local xmult
    if self.on_ground then
        -- TODO adjust this factor when on a slope, so ascending is harder than
        -- descending?  maybe even affect max_speed going uphill?
        xmult = self.ground_friction
    else
        xmult = self.aircontrol
    end
    --print()
    --print()
    --print("position", self.pos, "velocity", self.velocity)

    -- Explicit movement
    -- TODO should be whichever was pressed last?
    local pose = 'stand'
    if love.keyboard.isDown('right') then
        -- FIXME hmm is this the right way to handle a maximum walking speed?
        -- it obviously doesn't work correctly in another frame of reference
        if self.velocity.x < self.max_speed then
            self.velocity.x = self.velocity.x + self.xaccel * xmult * dt
        end
        self.facing_left = false
        pose = 'walk'
    elseif love.keyboard.isDown('left') then
        if self.velocity.x > -self.max_speed then
            self.velocity.x = self.velocity.x - self.xaccel * xmult * dt
        end
        self.facing_left = true
        pose = 'walk'
    end

    -- Jumping
    -- This uses the Sonic approach: pressing jump immediately sets (not
    -- increases!) the player's y velocity, and releasing jump lowers the y
    -- velocity to a threshold
    if love.keyboard.isDown('space') then
        if self.on_ground then
            if self.velocity.y > -self.jumpvel then
                self.velocity.y = -self.jumpvel
                self.on_ground = false
                -- FIXME kinda game-specific
                --game.resource_manager:get('assets/sounds/jump.ogg'):play()
            end
        end
    else
        if not self.on_ground then
            self.velocity.y = math.max(self.velocity.y, -self.jumpvel * self.jumpcap)
        end
    end

    -- Run the base logic to perform movement, collision, sprite updating, etc.
    actors_base.MobileActor.update(self, dt)

    -- FIXME uhh this sucks, but otherwise the death animation is clobbered by
    -- the bit below!  should death skip the rest of the actor's update cycle
    -- entirely, including activating any other collision?  should death only
    -- happen at the start of a frame?  should it be an event or something?
    if self.is_dead then
        return
    end

    -- Update pose depending on actual movement
    if self.on_ground then
    elseif self.velocity.y < 0 then
        pose = 'jump'
    elseif self.velocity.y > 0 then
        pose = 'fall'
    end
    -- TODO how do these work for things that aren't players?
    self.sprite:set_facing_right(not self.facing_left)
    self.sprite:set_pose(pose)

    -- TODO ugh, this whole block should probably be elsewhere; i need a way to
    -- check current touches anyway.  would be nice if it could hook into the
    -- physics system so i don't have to ask twice
    local hits = self._stupid_hits_hack
    self.touching_mechanism = nil
    debug_hits = hits
    for shape in pairs(hits) do
        local actor = worldscene.collider:get_owner(shape)
        if actor and actor.is_usable then
            self.touching_mechanism = actor
            break
        end
    end

    -- TODO this is stupid but i want a real exit door anyway
    -- TODO also it should fire an event or something
    local _, _, x1, _ = self.shape:bbox()
    if x1 >= worldscene.map.width then
        self.__EXIT = true
    end

    -- A floating player spawns particles
    -- FIXME this seems a prime candidate for entity/component or something,
    -- where floatiness is a child component with its own update behavior
    -- FIXME this is hardcoded for isaac's bbox, roughly -- should be smarter
    if self.is_floating and math.random() < dt * 8 then
        worldscene:add_actor(actors_misc.Particle(
            self.pos + Vector(math.random(-16, 16), 0), Vector(0, -32), Vector(0, 0),
            {255, 255, 255}, 1.5, true))
    end
end

function Player:draw()
    actors_base.MobileActor.draw(self)

    do return end
    if self.touching_mechanism then
        love.graphics.setColor(0, 64, 255, 128)
        self.touching_mechanism.shape:draw('fill')
        love.graphics.setColor(255, 255, 255)
    end
    if self.on_ground then
        love.graphics.setColor(255, 0, 0, 128)
    else
        love.graphics.setColor(0, 192, 0, 128)
    end
    self.shape:draw('fill')
    love.graphics.setColor(255, 255, 255)
end

function Player:damage(source, amount)
    -- Apply a force that shoves the player away from the source
    -- FIXME this should maybe be using the direction vector passed to
    -- on_collide instead?  this doesn't take collision boxes into account
    local offset = self.pos - source.pos
    local force = Vector(256, -32)
    if self.pos.x < source.pos.x then
        force.x = -force.x
    end
    self.velocity = self.velocity + force
end

local Gamestate = require 'vendor.hump.gamestate'
local DeadScene = require 'klinklang.scenes.dead'
-- TODO should other things also be able to die?
function Player:die()
    if not self.is_dead then
        local pose = 'die'
        self.sprite:set_pose(pose)
        self.is_dead = true
        -- TODO LOL THIS WILL NOT FLY but the problem with putting a check in
        -- WorldScene is that it will then explode.  so maybe this should fire an
        -- event?  hump has an events thing, right?  or, maybe knife, maybe let's
        -- switch to knife...
        -- TODO oh, it gets better: switch gamestate during an update means draw
        -- doesn't run this cycle, so you get a single black frame
        Gamestate.push(DeadScene())
    end
end

function Player:resurrect()
    if self.is_dead then
        self.is_dead = false
        -- Reset physics
        self.velocity = Vector(0, 0)
        -- FIXME this sounds reasonable, but if you resurrect /in place/ it's
        -- weird to change facing direction?  hmm
        self.facing_left = false
        -- This does a collision check without moving the player, which is a
        -- clever way to check whether they're on flat ground, update their
        -- sprite, etc. before any actual movement (or input!) happens.
        -- FIXME it's possible for the player to die again here, and that
        -- screws up the scene order and won't get you a dead scene, eek!
        -- FIXME this still takes player /input/, which makes it not solve the
        -- original problem i wanted of making on_ground be correct!
        self.on_ground = false
        self:update(0)
        -- Of course, the sprite doesn't actually update until the next sprite
        -- update, dangit.
        -- FIXME seems like i could reorder update() to fix this; otherwise
        -- there's a frame delay on ANY movement that changes the sprite
        self.sprite:update(0)
    end
end

-- TODO game-specific
function Player:grab_chip()
    local chip = self.ptrs.chip
    if not chip then
        return
    end

    chip:pick_up(self, function() self.gravity_multiplier_down = 0.25 end)
end
function Player:release_chip()
    local chip = self.ptrs.chip
    if not chip then
        return
    end

    -- Cancel approach, if Chip hadn't picked us up yet
    chip:cancel_approach(self)

    if chip.cargo == self then
        chip:set_down(self.pos, function()
            self.gravity_multiplier_down = 1
        end)
    end
end


return Player
