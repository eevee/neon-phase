local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local actors_misc = require 'klinklang.actors.misc'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'
local DialogueScene = require 'klinklang.scenes.dialogue'


local Twigs = actors_base.Actor:extend{
    name = 'twigs',
    sprite_name = 'twigs',

    is_usable = true,
}

local Anise = actors_base.Actor:extend{
    name = 'anise',
    sprite_name = 'anise',
    dialogue_position = 'right',
    dialogue_sprite_name = 'anise portrait',

    is_usable = true,
}

function Anise:on_use(activator)
    if activator.is_player then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = activator,
            chip = activator.ptrs.chip,
            anise = self,
        }, {
            -- Ring the bell
            { jump = 'out of items', condition = function() return game.progress.flags['anise: weird rectangle'] end },
            { "HI WELCOME TO STAR SHOP ANISE!!!!!!!! REOWOW!!! I'M STAR ANISE AND THESE DEALS CAN'T BE BEAT!!!!!", speaker = 'anise' },
            { "Is all of this stuff for sale?", speaker = 'kidneon' },
            { "Yes.", speaker = 'anise' },
            { "Cool.", speaker = 'kidneon' },

            -- FIXME should you be able to bail on this convo early?
            {
                label = 'buying options',
                speaker = 'anise',
                menu = {
                    { 'ringy bell', "ringy bell - makes cool noise when hit over and over" },
                    { 'broken star', "broken star - makes cool noise when hit over and over" },
                    { 'floor kibble', "floor kibble - tasty and easy to eat", condition = function()
                        return not game.progress.flags['anise: floor kibble']
                    end },
                    { 'mesh bag', "mesh bag - tasty and easy to eat", condition = function()
                        return not game.progress.flags['anise: mesh bag']
                    end },
                    { 'weird rectangle', "weird rectangle - useless piece of garbage. I'LL pay YOU to take this off my paws.", condition = function()
                        return game.progress.flags['anise: ringy bell']
                            and game.progress.flags['anise: broken star']
                            and game.progress.flags['anise: floor kibble']
                            and game.progress.flags['anise: mesh bag']
                    end },
                },
            },

            { label = 'ringy bell', set = 'anise: ringy bell' },
            { "I'm interested in the bell.", speaker = 'kidneon' },
            { "A fine choice. Aoowrrr. Makes an exquisite noise, does it not?", speaker = 'anise' },
            { "Uh, sure. How much for it?", speaker = 'kidneon' },
            { "It's not for sale.", speaker = 'anise' },
            { "...", speaker = 'kidneon' },
            { jump = 'buying options' },

            { label = 'broken star', set = 'anise: broken star' },
            { "What does the broken star do?", speaker = 'kidneon' },
            { "Well, if you drop it from up high, it breaks. I'd say that's its best feature.", speaker = 'anise' },
            { "But it's already broken.", speaker = 'kidneon' },
            { "No refunds.", speaker = 'anise' },
            { "What?", speaker = 'kidneon' },
            { "AOOOWRRR!!!!!", speaker = 'anise' },
            { jump = 'buying options' },

            { label = 'floor kibble', set = 'anise: floor kibble' },
            { "How much for the floor kibble?", speaker = 'kidneon' },
            { "Oh! Thanks for reminding me about that!", speaker = 'anise' },
            { "(The cat eats all of the remaining kibble.)", speaker = 'anise' },
            { jump = 'buying options' },

            { label = 'mesh bag', set = 'anise: mesh bag' },
            { "Could I have the mesh bag?", speaker = 'kidneon' },
            { "No. This is a shop, not a charity.", speaker = 'anise' },
            { "I meant--", speaker = 'kidneon' },
            { "(The cat shreds the mesh bag into useless ribbons.)", speaker = 'anise' },
            { "AOORWRRR!!!!!!!", speaker = 'anise' },
            { "On second thought...", speaker = 'kidneon' },
            { jump = 'buying options' },

            { label = 'weird rectangle', set = 'anise: weird rectangle' },
            { "How much for the memory chip?", speaker = 'kidneon' },
            { "The what?", speaker = 'anise' },
            { "The... the weird rectangle.", speaker = 'kidneon' },
            { "Oh, that. You don't want it. ", speaker = 'anise' },
            { "I kind of actually do, though.", speaker = 'kidneon' },
            { "No. Trust me. I've been trying to break it for ages, buddy. I've got a Space PhD in reverse engineering and even ~I~ can't figure this thing out.... Doesn't even", speaker = 'anise' },
            { "make a good noise when you hit it! It's useless, by any metric.", speaker = 'anise' },
            { "Say someone did want it, though. How much?", speaker = 'kidneon' },
            { "15 space dollars.", speaker = 'anise' },
            { "Er. Shoot. Is there any way we can work out a deal? ", speaker = 'kidneon' },
            { "20 space dollars.", speaker = 'anise' },
            { "I still definitely do not have that. Could we maybe make some kind of, I don't know... trade?", speaker = 'kidneon' },
            { "30 space dollars. My final offer.", speaker = 'anise' },
            { "I--", speaker = 'kidneon' },
            { "Fine. Hardball you want? Hardball you get. 50.", speaker = 'anise' },
            { "(Before you can reply, the cat throws both the memory chip and tiny scraps of paper through the shop window.)", speaker = 'anise' },
            { "TAKE YOUR STUPID RECTANGLE!!!! AOOOWRRR!!!!!", speaker = 'anise' },
            { "AND THEN RATE STAR SHOP ANISE 5 STARS ON NYELP!!! AAOORRW!!!!! ", speaker = 'anise' },
            { "Yeah. All right. I'll be sure to leave a... stellar review. Heh.", speaker = 'kidneon' },
            { "(The cat responds by putting a note on the counter.)", speaker = 'anise' },
            { bail = true },
            --(after getting the weird rectangle, end the convo with anise and have the memo key be spawned next to the shop)

            -- (after all items are checked and you get the memo key and talk to anise)
            { label = 'out of items' },
            { "Hey--", speaker = 'kidneon' },
            { "WE'RE OUT OF BUSINESS!!!! AOORWWW!!! CAN'T YOU READ???? ", speaker = 'anise' },
            { "(You look at the note the cat placed on the counter earlier. It's just a scrap of paper with a dirty pawprint on it.)", speaker = 'anise' },
        }))
    end
end


local MagnetGoat = actors_base.Actor:extend{
    name = 'magnet goat',
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


local Electroskunk2 = actors_base.Actor:extend{
    name = 'electroskunk 2',
    sprite_name = 'electroskunk 2',
}


return {
    MagnetGoat = MagnetGoat,
}
