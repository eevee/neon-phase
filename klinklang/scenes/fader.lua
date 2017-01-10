local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'
local flux = require 'vendor.flux'

local BaseScene = require 'klinklang.scenes.base'

local SceneFader = BaseScene:extend{
    __tostring = function(self) return "scenefader" end,

    wrapped = nil,
    _fluct = nil,
}

--[[
    Note that there are four combinations here, depending on whether you push
    or switch to the fader, and whether pop is true or false.

    push, pop: Fade from the current scene to itself.  to_scene should be the
    current scene.

    switch, pop: Fade from the current scene to whatever's beneath it.
    to_scene should be the underlying scene.  Most appropriate for fading out a
    wrapper scene.

    push, don't pop: Fade from the current scene to a new scene pushed on top
    of it.

    switch, don't pop: Fade from the current scene to a new scene replacing it.
]]

function SceneFader:init(to_scene, pop, time, color, onmidpoint)
    BaseScene.init(self)

    self.to_scene = to_scene
    self.pop = pop
    self.going = true
    self._fluct = flux.group()

    self.time = time
    self.color = {unpack(color)}
    self.color[4] = 0
    self.onmidpoint = onmidpoint
end

function SceneFader:enter(from_scene)
    self.from_scene = from_scene
    self._fluct:to(self.color, self.time, {[4] = 255})
        :oncomplete(function()
            self.going = false
            if self.onmidpoint then
                self.onmidpoint()
            end
        end)
        :after(self.time, {[4] = 0})
        :oncomplete(function()
            -- FIXME arrrggghhhh this shows a black frame!!
            if self.pop then
                Gamestate.pop()
                if Gamestate.current() ~= self.to_scene then
                    print("WARNING: inconsistent pop after fade", Gamestate.current(), self.to_scene)
                end
            else
                Gamestate.switch(self.to_scene)
            end
        end)
end

function SceneFader:update(dt)
    self._fluct:update(dt)
end

function SceneFader:draw()
    if self.going then
        self.from_scene:draw()
    else
        self.to_scene:draw()
    end

    love.graphics.push('all')
    love.graphics.setColor(self.color)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getDimensions())
    love.graphics.pop()
end

return SceneFader
