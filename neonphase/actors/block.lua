local Class = require 'vendor.hump.class'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'


local ShootableBlock = Class{
    __includes = actors_base.Actor,

    shape = whammo_shapes.Box(0, 0, 16, 16),
    anchor = Vector(0, 0),
    sprite_name = 'shootable block',

    breaking = false,
}

function ShootableBlock:blocks()
    return not self.breaking
end

function ShootableBlock:damage(source, amount)
    if self.breaking then
        return
    end
    self.sprite:set_pose('busted')
    worldscene.fluct:to(self, 0.3, {}):oncomplete(function()
        worldscene:remove_actor(self)
    end)
end


return {
    ShootableBlock = ShootableBlock,
}
