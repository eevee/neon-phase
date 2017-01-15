local tick = require 'vendor.tick'
local Gamestate = require 'vendor.hump.gamestate'

local BaseScene = require 'klinklang.scenes.base'
local DialogueScene = require 'klinklang.scenes.dialogue'

local UpgradeScene = BaseScene:extend{
    __tostring = function(self) return "upgradescene" end,
}

--------------------------------------------------------------------------------
-- hump.gamestate hooks

function UpgradeScene:init(chip, name_sfx, script, ...)
    BaseScene.init(self, ...)

    self.chip = chip
    self.name_sfx = name_sfx
    self.script = script
    self.timer = 0
    self.tick = tick.group()
end

function UpgradeScene:enter(previous_scene)
    self.wrapped = previous_scene

    self.upgrade_sprite = game.sprites['chip overlay']:instantiate()
    self.upgrade_sprite:set_facing_right(not self.chip.facing_left)

    local sfx = game.resource_manager:get('assets/sounds/upgrade.ogg')
    sfx:play()
    self.sfx_timer = sfx:getDuration()
    self.sfx2 = game.resource_manager:get(self.name_sfx)
    self.wait = self.sfx_timer + self.sfx2:getDuration() + 0.5
end

function UpgradeScene:update(dt)
    if self.sfx_timer > 0 then
        self.sfx_timer = self.sfx_timer - dt
        if self.sfx_timer < 0 then
            self.sfx2:play()
        end
    end

    self.timer = self.timer + dt
    -- FIXME i think i want to just play chip's animation twice?
    if self.timer > self.wait then
        local dialoguebox = game.resource_manager:load('assets/images/dialoguebox.png')
        Gamestate.switch(DialogueScene({
            -- Speakers
            kidneon = {
                position = 'left',
                sprite = game.sprites['kid neon portrait']:instantiate(),
                background = dialoguebox,
                pose = 'default',
            },
            chip = {
                position = 'right',
                sprite = game.sprites['chip portrait']:instantiate(),
                background = dialoguebox,
                pose = 'default',
            },
        },
            -- Script
            self.script
        ))
    else
        self.upgrade_sprite:update(dt)
    end
end

function UpgradeScene:draw()
    self.wrapped:draw()
    love.graphics.push()
    love.graphics.scale(game.scale, game.scale)
    love.graphics.translate(-worldscene.camera.x, -worldscene.camera.y)
    self.upgrade_sprite:draw_at(self.chip.pos)
    love.graphics.pop()
end

return UpgradeScene
