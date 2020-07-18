local tick = require 'vendor.tick'
local Vector = require 'vendor.hump.vector'

local BaseScene = require 'klinklang.scenes.base'
local Glitch = require 'neonphase.glitch'

local CreditsScene = BaseScene:extend{
    __tostring = function(self) return "credits" end,
}

function CreditsScene:init()
    self.music = game.resource_manager:load('assets/music/credits.ogg')
    self.music:setLooping(true)

    self.credits = {
        {
            sprite = game.sprites['anise']:instantiate(),
            portrait = game.sprites['anise portrait']:instantiate(),
            illus = love.graphics.newImage('assets/images/creditsanise.png'),
            name = 'STAR ANISE',
            quip = "Rich in friendship, broken toys",
        },
        {
            sprite = game.sprites['purrl']:instantiate(),
            portrait = game.sprites['purrl portrait']:instantiate(),
            illus = love.graphics.newImage('assets/images/creditspearl.png'),
            name = 'PURRL',
            quip = "Fishing for compliments",
        },
        {
            sprite = game.sprites['nyapo-ion']:instantiate(),
            portrait = game.sprites['nyapo-ion portrait']:instantiate(),
            illus = love.graphics.newImage('assets/images/creditsnapoleon.png'),
            name = 'NYAPO-ION',
            quip = "Enjoying his nyap",
        },
        {
            sprite = game.sprites['twig']:instantiate(),
            portrait = game.sprites['twig portrait']:instantiate(),
            illus = love.graphics.newImage('assets/images/creditstwig.png'),
            name = 'BRANCH CMDR\nTWIG',
            quip = "Returning at last to his own bed",
        },
        {
            sprite = game.sprites['stoplight cat']:instantiate(),
            portrait = game.sprites['stoplight cat portrait']:instantiate(),
            illus = love.graphics.newImage('assets/images/creditstrafficcat.png'),
            name = 'TRAFFIC CAT',
            quip = "Works hard every day",
        },
        {
            sprite = game.sprites['electroskunk']:instantiate(),
            sprite2 = game.sprites['electroskunk 2']:instantiate(),
            portrait = game.sprites['electroskunk portrait']:instantiate(),
            portrait2 = game.sprites['electroskunk 2 portrait']:instantiate(),
            illus = love.graphics.newImage('assets/images/creditsskunk.png'),
            name = 'ZAP + TRIXY',
            quip = "I bet you didn't realize they have four eyes",
        },
        {
            sprite = game.sprites['iridd']:instantiate(),
            sprite2 = game.sprites['smiley']:instantiate(),
            portrait = game.sprites['iridd portrait']:instantiate(),
            portrait2 = game.sprites['smiley portrait']:instantiate(),
            illus = love.graphics.newImage('assets/images/creditssmileyiridd.png'),
            name = 'IRIDD +\nSMILEY',
            quip = "Mostly harmless?",
        },
        {
            sprite = game.sprites['radio goat']:instantiate(),
            portrait = game.sprites['radio goat portrait']:instantiate(),
            illus = love.graphics.newImage('assets/images/creditsradiogoat.png'),
            name = 'STATIC',
            quip = "...",
        },
        {
            sprite = game.sprites['kid neon']:instantiate(),
            sprite2 = game.sprites['chip']:instantiate(),
            portrait = game.sprites['kid neon portrait']:instantiate(),
            portrait2 = game.sprites['chip portrait']:instantiate(),
            illus = love.graphics.newImage('assets/images/creditsneon.png'),
            name = 'KID NEON + CHIP',
            quip = "Tomorrow is another day, in another world",
            special_glitch = true,
        },
    }
    -- Vary Twig's ending
    if not game.progress.flags['fixed the ship'] then
        self.credits[4].illus = love.graphics.newImage('assets/images/creditstwig2.png')
        self.credits[4].quip = "Dreaming of home"
    end
    -- Only show the masked sun if you, uh, met them
    if game.progress.flags['bunker: visited weird place'] then
        local credit = {
            sprite = game.sprites['masked sun']:instantiate(),
            portrait = game.sprites['masked sun portrait']:instantiate(),
            illus = love.graphics.newImage('assets/images/creditsmaskedsun.png'),
            name = 'THE MASKED SUN',
            quip = "[error: string not found]",
        }
        -- Masked sun is not symmetrical, so un-flip
        credit.portrait:set_facing_right(false)
        table.insert(self.credits, credit)
    end

    -- Fix some flipped sprites, oof
    self.credits[4].sprite:set_facing_right(false)
    self.credits[6].sprite2:set_facing_right(false)
    self.credits[9].sprite:set_facing_right(false)
    -- Give Kid Neon and Chip actual poses
    self.credits[9].sprite:set_pose('walk')
    self.credits[9].sprite2:set_pose('jump')

    for _, credit in ipairs(self.credits) do
        credit.sprite:set_scale(2)
        if credit.sprite2 then
            credit.sprite2:set_scale(2)
        end
        if credit.portrait2 then
            credit.portrait2:set_facing_right(false)
        end
    end

    -- Finale
    self.us_illus = love.graphics.newImage('assets/images/creditslexypapaya.png')
    self.us_sprites = love.graphics.newImage('assets/images/portraitspapayalexy.png')
    local iw, ih = self.us_sprites:getDimensions()
    self.papaya_portrait = love.graphics.newQuad(0, 0, 80, 80, iw, ih)
    self.lexy_portrait = love.graphics.newQuad(80, 0, 80, 80, iw, ih)
    self.papaya_sprite = love.graphics.newQuad(48, 80, 32, 32, iw, ih)
    self.lexy_sprite = love.graphics.newQuad(80, 80, 32, 32, iw, ih)

    local w, h = game:getDimensions()
    self.y0 = h
    self.y00 = self.y0
    self.scroll_rate = 32

    self.font = love.graphics.newFont('assets/fonts/m5x7.ttf', 16 * 3)
    self.font = m5x7
    love.graphics.setFont(self.font)

    self.glitch = Glitch()
    self.glitch:play_glitch_effect()
    self.glitchier = Glitch()
    self.glitchier:play_credits_glitch_effect()
    self.canvas = love.graphics.newCanvas(w, h)
    self.neon_canvas = love.graphics.newCanvas(w, h)
    self.tfp_state = 0
    self.using_gamepad = worldscene.using_gamepad
    self.tick = tick.group()
end

function CreditsScene:enter()
    self.music:play()
end

function CreditsScene:update(dt)
    for _, credit in ipairs(self.credits) do
        credit.sprite:update(dt)
        if credit.sprite2 then
            credit.sprite2:update(dt)
        end
        credit.portrait:update(dt)
        if credit.portrait2 then
            credit.portrait2:update(dt)
        end
    end

    local reverse_rate = 1
    if self.done then
        reverse_rate = 0
    end
    if love.keyboard.isDown('up') then
        reverse_rate = -4
    end
    for i, joystick in ipairs(love.joystick.getJoysticks()) do
        if joystick:isGamepad() then
            if joystick:isGamepadDown('dpup') then
                reverse_rate = -4
            end
            local axis = joystick:getGamepadAxis('lefty')
            if axis < -0.25 then
                reverse_rate = axis * 16
                break
            end
        end
    end
    self.y0 = math.min(self.y00, self.y0 - self.scroll_rate * dt * reverse_rate)

    self.tick:update(dt)

    if self.done and not self.ever_done then
        self.ever_done = true
        self.tick:delay(function()
            self.tfp_state = 1
        end, 5)
    end
    if self.tfp_state == 1 and self.glitchier.active then
        self.tfp_state = 2
        self.tick:delay(function()
            self.tfp_state = 3
        end, 1)
    end
end

function CreditsScene:draw()
    love.graphics.push('all')
    love.graphics.setCanvas(self.neon_canvas)
    love.graphics.clear()
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear()

    local w, h = game:getDimensions()
    local margin = 16
    local y = math.floor(self.y0)

    love.graphics.printf("-- CREDITS --", 0, y, w, "center")
    y = y + self.font:getHeight() * 2

    for _, credit in ipairs(self.credits) do
        if credit.special_glitch then
            love.graphics.setCanvas(self.neon_canvas)
        else
            love.graphics.setCanvas(self.canvas)
        end
        local iw, ih = credit.illus:getDimensions()
        iw = iw * 2
        ih = ih * 2
        love.graphics.draw(credit.illus, margin, y, 0, 2)

        local textwidth = w - margin * 3 - iw
        local name_align = "left"
        local quip_align = "right"
        if credit.sprite2 then
            name_align = "center"
        end
        if credit.portrait2 then
            quip_align = "center"
        end

        love.graphics.setColor(1, 1, 1, 0.5)
        local portrait = credit.portrait
        local pw, ph = portrait:getDimensions()
        portrait:draw_at(Vector(margin * 2 + iw, y + ih - ph) + portrait.anchor)

        if credit.portrait2 then
            local portrait2 = credit.portrait2
            local p2w, p2h = credit.portrait2:getDimensions()
            portrait2:draw_at(Vector(w - p2w, y + ih - p2h) + portrait.anchor)
        end
        love.graphics.setColor(1, 1, 1)

        local sprite = credit.sprite
        local sw, sh = sprite:getDimensions()
        sprite:draw_at(Vector(w - margin - sw, y) + sprite.anchor)
        if credit.sprite2 then
            local sprite2 = credit.sprite2
            local s2w, sh = sprite2:getDimensions()
            sprite2:draw_at(Vector(margin * 2 + iw, y) + sprite2.anchor)
        end

        love.graphics.printf(credit.name, margin * 2 + iw, y, textwidth, name_align)
        love.graphics.printf(credit.quip, margin * 2 + iw, y + ih - ph, textwidth, quip_align)

        y = y + ih + margin * 4

        if y > h then
            break
        end
    end

    -- Final bit: us
    love.graphics.setCanvas(self.canvas)
    love.graphics.printf("-- OK ACTUAL CREDITS NOW --", 0, y, w, "center")
    y = y + self.font:getHeight() * 2
    local iw, ih = self.us_illus:getDimensions()
    iw = iw * 2
    ih = ih * 2
    love.graphics.draw(self.us_illus, (w - iw) / 2, y, 0, 2)
    love.graphics.draw(self.us_sprites, self.lexy_portrait, 80 + margin, y + ih - 80, 0, -1, 1)
    love.graphics.draw(self.us_sprites, self.papaya_portrait, w - margin - 80, y + ih - 80)
    y = y + ih + margin
    local textwidth = w - margin * 2
    love.graphics.printf("Eevee", margin, y, textwidth, "left")
    love.graphics.printf("GlitchedPuppet", margin, y, textwidth, "right")
    y = y + self.font:getHeight()
    love.graphics.setColor(0.75, 0.75, 0.75)
    love.graphics.printf("Code\nPolish\nYelling", margin, y, textwidth, "left")
    love.graphics.printf("Art\nConcept\nMusic", margin, y, textwidth, "right")
    y = y + self.font:getHeight() * 4 + margin * 4

    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf("Built with LÖVE\nand Daniel Linssen's sweet m5x7 font\nSource code: github.com/eevee/neon-phase\nSoundtrack, etc.: eevee.itch.io/neon-phase", margin, y, textwidth, "center")
    y = y + self.font:getHeight() * 4 + margin * 8

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Thanks for playing!", margin, y, textwidth, "center")
    y = y + self.font:getHeight() * 2
    if self.tfp_state == 1 or self.tfp_state == 2 then
        love.graphics.setCanvas(self.neon_canvas)
    end
    if self.tfp_state < 2 then
        love.graphics.printf("Made for Eevee's harebrained\nGames Made Quick jam 2017", margin, y, textwidth, "center")
    else
        local key
        if self.using_gamepad then
            key = "(Y)"
        else
            key = "[Q]"
        end
        love.graphics.printf(("That's it!  There's no more game.\nPress %s to quit.  Or scroll up."):format(key), margin, y, textwidth, "center")
    end
    love.graphics.setCanvas(self.canvas)
    y = y + self.font:getHeight() * 3
    love.graphics.setColor(0.5, 0.75, 2)
    love.graphics.printf("floraverse.com", margin, y, textwidth, "center")
    y = y + self.font:getHeight() + margin * 4

    love.graphics.printf("@eevee\neev.ee", 32 + margin * 2, y, w - (32 + margin * 2) * 2, "left")
    love.graphics.printf("@glitchedpuppet\nglitchedpuppet.com", 32 + margin * 2, y, w - (32 + margin * 2) * 2, "right")
    y = y + self.font:getHeight() * 2 + margin
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.us_sprites, self.lexy_sprite, margin + 32, y - margin - 32, 0, -1, 1)
    love.graphics.draw(self.us_sprites, self.papaya_sprite, w - margin, y - margin - 32, 0, -1, 1)

    self.done = y <= h

    love.graphics.pop()

    self.glitch:apply()
    love.graphics.draw(self.canvas, 0, 0, 0, game.scale, game.scale)
    love.graphics.setShader()
    self.glitchier:apply()
    love.graphics.draw(self.neon_canvas, 0, 0, 0, game.scale, game.scale)
    love.graphics.setShader()
end

function CreditsScene:resize(w, h)
    local w, h = game:getDimensions()
    self.canvas = love.graphics.newCanvas(w, h)
    self.neon_canvas = love.graphics.newCanvas(w, h)
end

function CreditsScene:keypressed(key, scancode, isrepeat)
    self.using_gamepad = false
    if self.done and self.tfp_state == 3 and key == 'q' then
        love.event.quit()
    end
end

function CreditsScene:gamepadpressed(joystick, button)
    self.using_gamepad = true
    if self.done and self.tfp_state == 3 and button == 'y' then
        love.event.quit()
    end
end

function CreditsScene:gamepadaxis(joystick, axis, value)
    if math.abs(value) > 0.25 then
        self.using_gamepad = true
    end
end

return CreditsScene
