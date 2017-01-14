local tick = require 'vendor.tick'
local Gamestate = require 'vendor.hump.gamestate'

local BaseScene = require 'klinklang.scenes.base'
local DialogueScene = require 'klinklang.scenes.dialogue'

local UpgradeScene = BaseScene:extend{
    __tostring = function(self) return "upgradescene" end,
}

--------------------------------------------------------------------------------
-- hump.gamestate hooks

function UpgradeScene:init(chip, ...)
    BaseScene.init(self, ...)

    self.chip = chip
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
    self.sfx2 = game.resource_manager:get('assets/sounds/energyball.ogg')
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
                sprite = game.sprites['kid neon portrait']:instantiate(),
                background = dialoguebox,
                pose = 'default',
            },
        }, {
            -- Script
            { "An upgrade chip.  Now I can...  ah...  upgrade Chip.", speaker = 'kidneon' },
            { "Boosting Chip's power efficiency by 3.2% should allow it to fire its pulse cannon, which will be useful for recharging devices.  I'll bind it to my [D] key.", speaker = 'kidneon' },
            { "[D] for...  devastating.", speaker = 'kidneon' },
        }))
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
