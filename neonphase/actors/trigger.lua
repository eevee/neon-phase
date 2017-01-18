local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'
local DialogueScene = require 'klinklang.scenes.dialogue'
local CreditsScene = require 'neonphase.scenes.credits'
local SceneFader = require 'klinklang.scenes.fader'


local TriggerZone = actors_base.BareActor:extend{
    name = 'trigger',
}

-- FIXME why don't i just take a shape?
function TriggerZone:init(pos, size, props)
    self.pos = pos
    self.shape = whammo_shapes.Box(pos.x, pos.y, size.x, size.y)

    if props then
        self.action = props.action
    end
    if not self.action then
        self.action = 'submap'
    end

    if self.action == 'submap' or self.action == 'summon anise' or self.action == 'anise wrong bell' or self.action == 'THE END' then
        self.is_usable = true
    end

    -- FIXME lol.  also shouldn't this be on_enter, really
    worldscene.collider:add(self.shape, self)
end

function TriggerZone:_check_for_softlock(actor)
    return (
        self.action == 'avoid softlock'
        and actor.is_player
        -- FIXME this is dumb but you should only be blocked one way
        and actor.pos.x < self.pos.x
        and actor.ptrs.chip
        and actor.ptrs.chip.cargo
        and actor.ptrs.chip.cargo ~= actor)
end

function TriggerZone:blocks(other, direction)
    if self:_check_for_softlock(other) then
        return true
    end
    return false
end

function TriggerZone:on_collide(other, direction)
    if not other.is_player then
        return
    end

    if self.action == 'empty house' then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = other,
            chip = other.ptrs.chip,
        }, {
            -- Script
            { "How'd I miss this place?", speaker = 'kidneon' },
            { "...", speaker = 'chip' },
            { "...", speaker = 'kidneon' },
            { "I guess it doesn't matter either way. There's nothing here for us.", speaker = 'kidneon' },
        }))
        worldscene:remove_actor(self)
    -- FIXME direction is the direction of movement, not the direction OR side we're being hit, which is a shame
    elseif self:_check_for_softlock(other) and direction.x > 0 then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = other,
            chip = other.ptrs.chip,
        }, {
            -- Script
            { "ERROR.  CARRYING AN OBJECT DOWN HERE MAY RENDER THIS PUZZLE IMPOSSIBLE.", speaker = 'chip' },
            { "What shoddy design.", speaker = 'kidneon' },
        }))
    end
end

function TriggerZone:on_use(activator)
    if not activator.is_player then
        return
    end

    -- FIXME my map has props for this stuff, which i should probably be using here
    if self.action == 'submap' then
        if worldscene.submap then
            worldscene:leave_submap()
        else
            worldscene:enter_submap('inside house 1')
        end
    elseif self.action == 'summon anise' or self.action == 'anise wrong bell' then
        worldscene:remove_actor(self)

        -- FIXME ugh
        local anise
        for _, actor in ipairs(worldscene.actors) do
            if actor.name == 'anise' then
                anise = actor
                break
            end
        end
        if anise then
            if self.action == 'summon anise' then
                anise:move_to_stall()
            else
                anise:wrong_bell(activator)
            end
        end
    elseif self.action == 'THE END' then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = activator,
            chip = activator.ptrs.chip,
        }, {
            -- Script
            { jump = 'all keys', condition = function() return game.progress.keys and game.progress.keys >= 5 end },
            { jump = 'some keys', condition = function() return game.progress.keys and game.progress.keys > 0 end },
            { "It's locked. I need to find all the key data. It's usually around here somewhere.", speaker = 'kidneon' },
            { bail = true },

            { label = 'some keys' },
            { "It's locked. I don't have enough key data. Gotta keep looking.", speaker = 'kidneon' },
            { bail = true },

            { label = 'all keys' },
            { "Looks like we found all the key data.", speaker = 'kidneon' },
            { "BZZT.  WITH TIME TO SPARE.", speaker = 'chip' },
            { "Is there anything we forgot to do?  We won't be coming back here.", speaker = 'kidneon' },
            {
                speaker = 'kidneon',
                menu = {
                    { 'leave', "(Nah, let's go.)" },
                    { 'hesitate', "(Maybe one more look around.)" },
                },
            },
            { label = 'hesitate' },
            { "If we have the time, there's no harm in hanging back for a little while.", speaker = 'kidneon' },
            { "NOT TOO LONG.  EARLY IS PREFERABLE TO LATE, BZZT.", speaker = 'chip' },
            { bail = true },
            { label = 'leave' },
            { "DOES IT MATTER?", speaker = 'chip' },
            { "I guess not.", speaker = 'kidneon' },
            {
                "Here we go...",
                "And...",
                "Unlocked.",
                "You know...",
                "It's weird, but I kind of like it here. I don't know if it's the familiarity, or... that overwhelming feeling of deja vu, maybe. ",
                "...Haha. Yeah. I think that's why I like it. Simply because I know it. No regard for if it's good or bad or healthy or not.",
                "That's really weird, isn't it?",
                "I know it's dangerous, but... but this place is really familiar to me, so I keep coming back.",
                "Even if I can't really remember it...",
                "I want to come back.",
                "I don't really know what I'm supposed to do with that feeling. ",
                "Is it bad? ",
                "...",
                "No, it's not bad... ",
                "Of course it's not bad.",
                "Because it's not anything. ",
                "It's wrong to even try to quantify it by some arbitrary moral standards.",
                "It is what it is, I guess.",
                "An urge, based on an echo of the past.",
                "...",
                "Do you ever get that, Chip? Do you ever get deja vu? Or anything like it?",
                speaker = 'kidneon',
            },
            { "NO. MY MEMORY DATA IS NEVER IN FLUX LIKE YOURS.", speaker = 'chip' },
            { "Yeah... Yeah. I know. I don't know why I asked. Sorry.", speaker = 'kidneon' },
            { "So. About how long do you estimate until it'll be safe to come back out?", speaker = 'kidneon' },
            { "BZZT. DIFFICULT TO ESTIMATE. WILD FLUCTUATIONS PROJECTED TO OCCUR FOR UNKNOWN PERIODS OF TIME.", speaker = 'chip' },
            { "Oh, well. C'mon, then. Let's go wait it out.", speaker = 'kidneon' },
            { execute = function()
                local fader = SceneFader(CreditsScene(), false, 2, {0, 0, 0})
                if worldscene.music then
                    fader:fade_out_music(worldscene.music)
                end
                Gamestate.switch(fader)
            end },
            -- FIXME this seems to be necessary idk
            { "...", speaker = 'chip' },
        }))
    end
end


return TriggerZone
