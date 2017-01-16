local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'
local DialogueScene = require 'klinklang.scenes.dialogue'


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

    -- FIXME should probably have a trigger...  mode
    if self.action == 'submap' or self.action == 'summon anise' then
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
    -- FIXME direction is the direction of movement, not the direction OR side we're being hit, which is a shame
    if self:_check_for_softlock(other) and direction.x > 0 then
        local dialoguebox = game.resource_manager:load('assets/images/dialoguebox.png')
        Gamestate.push(DialogueScene({
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
        }, {
            -- Script
            { "ERROR.  CARRYING AN OBJECT DOWN HERE MAY RENDER THIS PUZZLE IMPOSSIBLE.", speaker = 'chip' },
            { "What shoddy design.", speaker = 'kidneon' },
        }))
    end
end

function TriggerZone:on_use(activator)
    -- FIXME my map has props for this stuff, which i should probably be using here
    if self.action == 'submap' then
        if worldscene.submap then
            worldscene:leave_submap()
        else
            worldscene:enter_submap('inside house 1')
        end
    elseif self.action == 'summon anise' then
        worldscene:remove_actor(self)

        -- FIXME ugh
        local anise
        for _, actor in ipairs(worldscene.actors) do
            if actor.name == 'anise' and not actor.has_moved then
                anise = actor
                break
            end
        end
        if anise then
            anise:move_to_stall()
        end
    end
end


return TriggerZone
