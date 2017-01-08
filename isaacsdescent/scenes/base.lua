--[[
All this does is rename Gamestate's init hook to scene_init, so it doesn't
conflict with Class.init.
]]
local Class = require 'vendor.hump.class'

local BaseScene = Class{
    scene_init = function() end,
}

function BaseScene:init()
    self.init = self.scene_init
end

return BaseScene
