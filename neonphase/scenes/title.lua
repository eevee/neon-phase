local anim8 = require 'vendor.anim8'
local flux = require 'vendor.flux'
local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local BaseScene = require 'klinklang.scenes.base'
local SceneFader = require 'klinklang.scenes.fader'
local Glitch = require 'neonphase.glitch'

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

    self.logo = love.graphics.newImage('assets/images/FLORAVERSE.png')
    self.logo:setFilter('linear', 'linear')
    self.opacity = 1
    self.showing_logo = true

    self.title_image = love.graphics.newImage('assets/images/title.png')
    local grid = anim8.newGrid(800, 480, self.title_image:getDimensions())
    self.title_anim = anim8.newAnimation(grid('2-6', 1, 1, 1), { ['1-5'] = 0.1, [6] = 2 })

    self.glitch = Glitch()
    self.glitch:play_very_glitch_effect()
    self.flux = flux.group()

    self.map_path = map_path
    self.load_state = 0
end

function TitleScene:enter()
    self.music:play()
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

    self.flux:update(dt)
    self.title_anim:update(dt)
end

function TitleScene:draw()
    if self.load_state == 0 then
        self.load_state = 1
    end

    love.graphics.push('all')
    local n = self.opacity * 255
    love.graphics.setColor(n, n, n)
    if self.showing_logo then
        local w, h = love.graphics.getDimensions()
        local iw, ih = self.logo:getDimensions()
        local scale = math.min(w / iw, h / ih) * 0.75
        local siw = iw * scale
        local sih = ih * scale
        love.graphics.rectangle('fill', 0, 0, w, h)
        self.glitch:apply()
        love.graphics.draw(self.logo, (w - siw) / 2, (h - sih) / 2, 0, scale)
        love.graphics.setShader()
        local c = self.opacity * 192
        love.graphics.setColor(c, c, c)
        love.graphics.setFont(m5x7small)
        love.graphics.printf("v" .. game.VERSION, 0, h - m5x7small:getHeight() - 4, w - 4, "right")
    else
        love.graphics.scale(game.scale, game.scale)

        local w, h = game:getDimensions()
        self.title_anim:draw(self.title_image, math.floor((w - 800) / 2), math.floor((h - 480) / 2))
    end
    love.graphics.pop()
end

function TitleScene:_advance()
    if self.showing_logo then
        self.flux:to(self, 0.5, { opacity = 0 })
            :oncomplete(function() self.showing_logo = false end)
            :after(0.5, { opacity = 1 })
            :oncomplete(function() self.can_continue = true end)
        return
    end
    if self.can_continue then
        Gamestate.switch(SceneFader(self.next_scene, false, 1.0, {0, 0, 0}))
    end
end

function TitleScene:keypressed(key, scancode, isrepeat)
    if love.keyboard.isDown('lalt', 'ralt') then
        return
    end
    if isrepeat then
        return
    end
    self:_advance()
end

function TitleScene:gamepadpressed(joystick, button)
    self:_advance()
end


return TitleScene
