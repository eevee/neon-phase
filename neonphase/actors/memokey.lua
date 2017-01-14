local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local DialogueScene = require 'klinklang.scenes.dialogue'


local MemoKey = actors_base.Actor:extend{
    name = 'memo key',
    sprite_name = 'memo key',
}

function MemoKey:blocks()
    return false
end

function MemoKey:on_collide(other, direction)
    if other.is_player then
        worldscene:remove_actor(self)
        local dialoguebox = game.resource_manager:load('assets/images/dialoguebox.png')
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = {
                sprite = game.sprites['kid neon portrait']:instantiate(),
                background = dialoguebox,
                pose = 'default',
            },
        }, {
            -- Script
            { "It's a memo key.", speaker = 'kidneon' },
            { "I don't know what that means.  I'll send myself a direct memo reminding me to wikky it later.", speaker = 'kidneon' },
        }))
    end
end


return {
    MemoKey = MemoKey,
}
