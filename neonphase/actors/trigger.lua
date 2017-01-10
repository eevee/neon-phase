local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'


local TriggerZone = actors_base.BareActor:extend{
    name = 'trigger',
    is_usable = true,
}

-- FIXME why don't i just take a shape?
function TriggerZone:init(pos, size)
    self.pos = pos
    self.shape = whammo_shapes.Box(pos.x, pos.y, size.x, size.y)
    -- FIXME lol.  also shouldn't this be on_enter, really
    worldscene.collider:add(self.shape, self)
end

function TriggerZone:on_use(activator)
    -- FIXME my map has props for this stuff, which i should probably be using here
    if worldscene.submap then
        worldscene:leave_submap()
    else
        worldscene:enter_submap('inside house 1')
    end
end


return TriggerZone
