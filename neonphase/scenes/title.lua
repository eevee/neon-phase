local anim8 = require 'vendor.anim8'
local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local BaseScene = require 'klinklang.scenes.base'
local SceneFader = require 'klinklang.scenes.fader'

local TitleScene = BaseScene:extend{
    __tostring = function(self) return "title" end,
}

-- FIXME when fading worldscene back in, camera is in the wrong place
-- FIXME should this actually fade, or should it glitch
-- FIXME this should appear /while/ worldscene is loading, and show "loading..." or "press a key" in the lower right
function TitleScene:init(next_scene, map_path)
    TitleScene.__super.init(self)
    self.next_scene = next_scene

    self.music = love.audio.newSource('assets/music/title.ogg')
    self.music:setLooping(true)
    self.music:play()

    self.title_image = love.graphics.newImage('assets/images/title.png')
    local grid = anim8.newGrid(800, 480, self.title_image:getDimensions())
    self.title_anim = anim8.newAnimation(grid('1-6', 1), { 2, ['2-6'] = 0.1 })

    self.map_path = map_path
    self.load_state = 0
end

function TitleScene:update(dt)
    if self.load_state == 1 then
        -- Only start to load the map AFTER we've drawn at least one frame, so
        -- the player isn't staring at a blank screen
        local tiledmap = require('klinklang.tiledmap')
        local map = tiledmap.TiledMap(self.map_path, game.resource_manager)
        self.next_scene:load_map(map)
        self.load_state = 2
    end

    self.title_anim:update(dt)
end

function TitleScene:draw()
    if self.load_state == 0 then
        self.load_state = 1
    end

    love.graphics.push('all')
    love.graphics.scale(game.scale, game.scale)

    local w, h = game:getDimensions()
    self.title_anim:draw(self.title_image, math.floor((w - 800) / 2), math.floor((h - 480) / 2))

    love.graphics.pop()
end

function TitleScene:keypressed(key, scancode, isrepeat)
    Gamestate.switch(SceneFader(self.next_scene, false, 1.0, {0, 0, 0}))
end


return TitleScene
