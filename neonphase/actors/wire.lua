local Class = require 'vendor.hump.class'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'


local WIRE_CONNECTIONS = {
    north = Vector(0, -16),
    south = Vector(0, 16),
    east = Vector(16, 0),
    west = Vector(-16, 0),
}

local Wirable = Class{
    __includes = actors_base.Actor,

    connections = {},
    powered = 0,
    can_emit = true,
    can_receive = true,
}

function Wirable:init(...)
    actors_base.Actor.init(self, ...)

    self.live_connections = setmetatable({}, { __mode = 'k' })
end

function Wirable:on_enter()
    -- FIXME get this stuff from the physics engine
    for _, actor in ipairs(worldscene.actors) do
        if actor._receive_pulse then
            local direction = actor.pos - self.pos
            local is_connection = false
            for _, conn in ipairs(self.connections) do
                if conn == direction then
                    is_connection = true
                    break
                end
            end
            local is_reverse_connection = false
            for _, conn in ipairs(actor.connections) do
                if conn == -direction then
                    is_reverse_connection = true
                    break
                end
            end
            -- FIXME is...  this...  right?  need to be connected both ways, right?  seems right...
            if is_connection and is_reverse_connection then
                -- FIXME seems invasive
                self:_receive_pulse(actor.powered > 0, actor)
                if actor.powered > 0 then
                    actor.live_connections[self] = 1
                else
                    actor.live_connections[self] = 0
                end
            end
        end
    end

    self:_emit_pulse(self.powered > 0)
end

function Wirable:on_leave()
    self:_emit_pulse(false)
    -- FIXME this seems, idk, kinda silly
    for connection, state in pairs(self.live_connections) do
        connection.live_connections[self] = nil
    end
    self.live_connections = {}
end

function Wirable:_emit_pulse(value)
    if not self.can_emit then
        return
    end
    for connection, state in pairs(self.live_connections) do
        if value == true and state == 0 then
            connection:_receive_pulse(value, self)
            self.live_connections[connection] = 1
        elseif value == false and state == 1 then
            connection:_receive_pulse(value, self)
            self.live_connections[connection] = 0
        end
    end
end

function Wirable:_receive_pulse(value, source)
    if not self.can_receive then
        return
    end
    if self.live_connections[source] == 1 then
        return
    end

    local orig = self.powered
    if value == true then
        if self.live_connections[source] ~= -1 then
            self.powered = self.powered + 1
        end
        self.live_connections[source] = -1
    else
        if self.live_connections[source] == -1 then
            self.powered = self.powered - 1
        end
        self.live_connections[source] = 0
    end

    if orig == 0 and self.powered > 0 then
        self._pending_pulse = true
    elseif orig > 0 and self.powered == 0 then
        self._pending_pulse = false
    end
end

function Wirable:update(dt)
    actors_base.Actor.update(self, dt)

    -- FIXME hm, this carries pulses in frames rather than in absolute time
    if self._pending_pulse ~= nil then
        self:_emit_pulse(self._pending_pulse)
        self._pending_pulse = nil
    end
end

function Wirable:draw()
    actors_base.Actor.draw(self)

    --[[
    if self.powered > 0 then
        love.graphics.setColor(255, 255, 0, 128)
        self.shape:draw('fill')
    end
    for connection, state in pairs(self.live_connections) do
        local direction = connection.pos - self.pos
        if state == -1 then
            love.graphics.setColor(0, 255, 0)
        elseif state == 1 then
            love.graphics.setColor(255, 0, 0)
        else
            love.graphics.setColor(255, 255, 0)
        end
        local midpoint = self.pos + direction / 4
        local perp = direction:perpendicular() / 4
        love.graphics.line(midpoint.x - perp.x, midpoint.y - perp.y, midpoint.x + perp.x, midpoint.y + perp.y)
    end
    love.graphics.setColor(255, 255, 255)
    ]]
end
            


local Emitter = Class{
    __includes = Wirable,

    sprite_name = 'emitter',
    shape = whammo_shapes.Box(4, 4, 8, 8),
    anchor = Vector(8, 8),

    connections = {Vector(0, 16)},
    powered = 1,
    can_receive = false,
}


local WireNS = Class{
    __includes = Wirable,

    sprite_name = 'wire ns',
    shape = whammo_shapes.Box(4, 4, 8, 8),
    anchor = Vector(8, 8),

    connections = {Vector(0, -16), Vector(0, 16)},
}

local WireNE = Class{
    __includes = Wirable,

    sprite_name = 'wire ne',
    shape = whammo_shapes.Box(4, 4, 8, 8),
    anchor = Vector(8, 8),

    connections = {Vector(0, -16), Vector(16, 0)},
}

local WireNW = Class{
    __includes = Wirable,

    sprite_name = 'wire nw',
    shape = whammo_shapes.Box(4, 4, 8, 8),
    anchor = Vector(8, 8),

    connections = {Vector(0, -16), Vector(-16, 0)},
}

local WireEW = Class{
    __includes = Wirable,

    sprite_name = 'wire ew',
    shape = whammo_shapes.Box(4, 4, 8, 8),
    anchor = Vector(8, 8),

    connections = {Vector(16, 0), Vector(-16, 0)},
}

local Bulb = Class{
    __includes = Wirable,

    sprite_name = 'bulb',
    shape = whammo_shapes.Box(4, 4, 8, 8),
    anchor = Vector(8, 8),

    connections = {Vector(0, 16)},
    can_emit = false,
}

function Bulb:_receive_pulse(value, source)
    Wirable._receive_pulse(self, value, source)

    if self.powered > 0 then
        self.sprite:set_pose('on')
    else
        self.sprite:set_pose('off')
    end
end


local WirePlugNE = Class{
    __includes = Wirable,

    sprite_name = 'wire plug ne',
    shape = whammo_shapes.Box(4, 4, 8, 8),
    anchor = Vector(8, 8),

    connections = {Vector(0, -16), Vector(16, 0)},
}

local WireSocket = Class{
    __includes = Wirable,

    sprite_name = 'wire socket',
    shape = whammo_shapes.Box(4, 4, 8, 8),
    anchor = Vector(8, 8),

    is_usable = true,
}

function WireSocket:on_enter()
    local plug = WirePlugNE(self.pos)
    self.ptrs.plug = plug
    worldscene:add_actor(plug)
end

function WireSocket:on_use(activator)
    -- FIXME this is invasive; chip needs an api for taking a thing, and probably a little animation too
    if activator.is_player and self.ptrs.plug and not activator.ptrs.chip.holding then
        activator.ptrs.chip.holding = self.ptrs.plug
        worldscene:remove_actor(self.ptrs.plug)
        self.ptrs.plug = nil
    elseif activator.is_player and not self.ptrs.plug and activator.ptrs.chip.holding then
        -- FIXME only if holding a plug!
        local plug = activator.ptrs.chip.holding
        activator.ptrs.chip.holding = nil
        plug.pos = self.pos:clone()
        self.ptrs.plug = plug
        worldscene:add_actor(plug)
    end
end


return {
    Wire = Wire,
    Bulb = Bulb,
    WireNS = WireNS,
    WireNE = WireNE,
    WireNW = WireNW,
    WireEW = WireEW,
    Emitter = Emitter,
    WirePlugNE = WirePlugNE,
    WireSocket = WireSocket,
}
