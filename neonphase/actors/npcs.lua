local Class = require 'vendor.hump.class'
local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local actors_misc = require 'klinklang.actors.misc'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'
local DialogueScene = require 'klinklang.scenes.dialogue'


local MagnetGoat = Class{
    __includes = actors_base.Actor,

    shape = whammo_shapes.Box(0, 0, 32, 32),
    anchor = Vector(16, 32),
    sprite_name = 'magnet goat',

    is_usable = true,
}

function MagnetGoat:on_use(activator)
    if activator.is_player then
        local dialoguebox = game.resource_manager:load('assets/images/dialoguebox.png')
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = {
                sprite = game.sprites['kid neon portrait']:instantiate(),
                background = dialoguebox,
                pose = 'default',
            },
            magnetgoat = {
                sprite = game.sprites['magnet goat portrait']:instantiate(),
                background = dialoguebox,
                pose = 'default',
            },
        }, {
            -- Script
            { "Greetings, stranger.", speaker = 'kidneon' },
            { "Go away.", speaker = 'magnetgoat' },
        }))
    end
end


return {
    MagnetGoat = MagnetGoat,
}
