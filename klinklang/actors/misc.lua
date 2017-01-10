local Vector = require 'vendor.hump.vector'

local Object = require 'klinklang.object'
local actors_base = require 'klinklang.actors.base'
local whammo_shapes = require 'klinklang.whammo.shapes'


local Particle = actors_base.BareActor:extend()

function Particle:init(position, velocity, acceleration, color, ttl, fadeout)
    self.pos = position
    self.velocity = velocity
    self.acceleration = acceleration
    self.color = color
    self.ttl = ttl
    self.original_ttl = ttl
    self.fadeout = fadeout
end

function Particle:update(dt)
    self.velocity = self.velocity + self.acceleration * dt
    self.pos = self.pos + self.velocity * dt

    self.ttl = self.ttl - dt
    if self.ttl < 0 then
        worldscene:remove_actor(self)
    end
end

function Particle:draw()
    love.graphics.push('all')
    if self.fadeout then
        local r, g, b, a = unpack(self.color)
        if a == nil then
            a = 255
        end
        a = a * (self.ttl / self.original_ttl)
        love.graphics.setColor(r, g, b, a)
    else
        love.graphics.setColor(unpack(self.color))
    end
    love.graphics.points(self.pos:unpack())
    love.graphics.pop()
end


return {
    Particle = Particle,
}
