local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local actors_misc = require 'klinklang.actors.misc'
local Player = require 'klinklang.actors.player'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'
local DialogueScene = require 'klinklang.scenes.dialogue'
local SceneFader = require 'klinklang.scenes.fader'

local MemoKey = require 'neonphase.actors.memokey'


-- TODO this is bad
local function _find_actor_by_type_name(name)
    for _, actor in ipairs(worldscene.actors) do
        if actor.name == name then
            return actor
        end
    end
end


local PlotCover = actors_base.Actor:extend{
    name = 'plot cover shh',
    sprite_name = 'plot cover shh',
    z = 100000,
}

function PlotCover:blocks()
    return true
end


local function _graveyard_convo(player)
    Gamestate.push(DialogueScene({
        kidneon = player,
        chip = player.ptrs.chip,
    }, {
        { "...", speaker = 'kidneon' },
        { "BZZT. GOOD MORNING.", speaker = 'chip' },
        { "What? ", speaker = 'kidneon' },
        { "What?! Where are we?", speaker = 'kidneon' },
        { "SECTOR TY-045F. TESLIC YARD'S OUTER RING.", speaker = 'chip' },
        { "I don't recognize this place. How'd we get here?", speaker = 'kidneon' },
        { "YOU WALKED HERE AND I FOLLOWED.", speaker = 'chip' },
        {
            "I don't... remember doing that.",
            "But here we are, so.",
            "Damn it. What were we doing before that?",
            speaker = 'kidneon',
        },
        { "COLLECTING KEY DATA.", speaker = 'chip' },
        { "No, like...", speaker = 'kidneon' },
        { "weren't we going somewhere?", speaker = 'kidneon' },
        { "BZZT. WE ARE TRYING TO GO INSIDE THE LOCKED BUILDING.", speaker = 'chip' },
        {
            "Okay. All right.",
            "...",
            "No. That can't be it.",
            "What really happened? Tell me.",
            speaker = 'kidneon',
        },
        { "ENTERING IDLE MODE.", speaker = 'chip' },
        { "...", speaker = 'kidneon' },
    }))
end


local MaskedSun = actors_base.Actor:extend{
    name = 'masked sun',
    sprite_name = 'masked sun',
    dialogue_position = 'right',
    dialogue_sprite_name = 'masked sun portrait',
    dialogue_background = 'assets/images/voiddialoguebox.png',
}


local VoidPlayer = Player:extend{
    name = 'void player',
    sprite_name = 'void player',
    dialogue_position = 'left',
    dialogue_sprite_name = 'void player portrait',
    dialogue_background = 'assets/images/voiddialoguebox.png',
    dialogue_color = {64, 64, 64},

    xaccel = 600,
    -- FIXME friction is stupid
    friction = 400,
    max_speed = 60,
}

function VoidPlayer:on_enter()
    -- Don't spawn a Chip
end

function VoidPlayer:on_leave()
    -- Don't take a Chip either
end

function VoidPlayer:decide_jump()
    -- Nope
end

function VoidPlayer:update(...)
    if self.done then
    elseif self.pos.x >= 1216 then
        self.done = true
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = self,
            maskedsun = _find_actor_by_type_name('masked sun'),
        }, {
            { "This isn't an ideal outcome.", speaker = 'maskedsun' },
            { "it's over", speaker = 'kidneon' },
            { "As a matter of fact, it's hardly an outcome at all. This isn't how it ends. So, get up.", speaker = 'maskedsun' },
            { "no point", speaker = 'kidneon' },
            { "Wrong. It's important. To keep thinking and imagining and dreaming. That's the point. To do better. To be better. Everyone's in this, together.", speaker = 'maskedsun' },
            { "tired", speaker = 'kidneon' },
            { "Everyone's tired. Everyone's stretched so, so thin. ", speaker = 'maskedsun' },
            { "Keep going. Can't give up. Must keep going. We've got to keep going.", speaker = 'maskedsun' },
            { "it's so hard", speaker = 'kidneon' },
            {
                "We've achieved so much already...",
                "But...",
                "There's nothing left for us if I give up now. ",
                "Nothing left for us, and nothing left for anyone.",
                "And yes, it's difficult.",
                "It's a very difficult role.",
                "Of course it is! Because it's mine. It's ours!",
                "And that's what makes it so important!",
                "A sacred chance, to learn anew!",
                "And in that role... in our difficult existence...",
                "There is value.",
                "Even if I don't know how to try harder...",
                "Or better...",
                "I'm trying.",
                "And for now, that is enough.",
                "Let's go.",
                speaker = 'maskedsun',
            },
            {
                execute = function()
                    worldscene.glitch:play_extreme_glitch_transition()
                    worldscene.tick:delay(function()
                        local fader = SceneFader(worldscene, true, 3.75, {255, 255, 255}, function()
                            worldscene:remove_actor(worldscene.player)
                            worldscene.player = worldscene.stashed_player
                            worldscene.player:move_to(Vector(96, 1872))
                            worldscene.player.chip:teleport_to_shoulder(worldscene.player)
                            worldscene:load_map(game.resource_manager:get("data/maps/map.tmx.json"))
                            worldscene:remove_actor(_find_actor_by_type_name('plot cover shh'))
                            worldscene:add_actor(worldscene.player)
                            worldscene:update_camera()
                            -- A zero update fixes state (like whether the
                            -- player was touching something) without advancing
                            -- time
                            worldscene:update(0)
                            -- And this fires the graveyard convo the moment
                            -- the world scene regains control
                            worldscene.tick:delay(function()
                                _graveyard_convo(worldscene.player)
                            end, 0)
                        end)
                        if worldscene.music then
                            fader:fade_out_music(worldscene.music)
                        end
                        Gamestate.push(fader)
                    end, 0.25)
                end
            },
        }))
    else
        VoidPlayer.__super.update(self, ...)
    end
end

local VOID_TEXTS = {
    "too much",
    "it's too much",
    "going back is hard",
    "can't",
    "don't want to",
    "it's over",
    "never worth it",
    "can't do anything",
    "can't be anything",
    "...",
    "why bother",
}
function VoidPlayer:draw()
    VoidPlayer.__super.draw(self)

    local text_duration = 4
    local i = math.min(#VOID_TEXTS, math.floor(self.timer / text_duration) + 1)
    local t = self.timer % text_duration

    if t < text_duration - 1 then
        love.graphics.push('all')
        local alpha = 255
        if t < 0.5 then
            alpha = alpha * t
        elseif t > text_duration - 1.5 then
            alpha = alpha * (text_duration - t - 1)
        end
        love.graphics.setColor(0, 0, 0, alpha)
        local w, h = game:getDimensions()
        love.graphics.printf(VOID_TEXTS[i], worldscene.camera.x, worldscene.camera.y + 80, w, "center")
        love.graphics.pop()
    end
end


local Bunker = actors_base.BareActor:extend{
    shape = whammo_shapes.Box(646, 714, 76, 6),

    is_usable = true,
}

function Bunker:on_use(activator)
    if activator.is_player then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = activator,
            chip = activator.ptrs.chip,
        }, {
            -- Script
            { jump = 'second time', condition = 'bunker: visited weird place' },
            { set = 'bunker: visited weird place' },
            { "Hey, Chip. Last chance. I'm not gonna let you get away with pretending like you already knew about whatever we find.", speaker = 'kidneon' },
            { "...unless you tell me right now and end up being right, I mean.", speaker = 'kidneon' },
            { "YOU WILL FIND NOTHING.", speaker = 'chip' },
            { "Chip...", speaker = 'kidneon' },
            { "THERE IS STILL TIME TO CHANGE YOUR MIND.", speaker = 'chip' },
            { "What? No. Why would I want to do that?", speaker = 'kidneon' },
            { "...", speaker = 'chip' },
            {
                speaker = 'kidneon',
                menu = {
                    { 'continue', "(Enter the bunker.)" },
                    { 'continue', "(Enter the bunker.)" },
                },
            },
            { label = 'continue' },
            { execute = function()
                local fader = SceneFader(worldscene, true, 1, {0, 0, 0}, function()
                    local tiledmap = require('klinklang.tiledmap')
                    map = tiledmap.TiledMap("data/maps/weirdplace.tmx.json", game.resource_manager)
                    -- Fuck it
                    worldscene.stashed_player = worldscene.player
                    worldscene:remove_actor(worldscene.player)
                    worldscene.player = VoidPlayer(worldscene.player.pos)
                    worldscene:load_map(map)
                    worldscene.glitch:play_very_glitch_effect()
                    worldscene.music = love.audio.newSource('assets/music/weirdplace.ogg')
                    worldscene.music:setLooping(true)
                    worldscene.music:play()
                end)
                if worldscene.music then
                    fader:fade_out_music(worldscene.music)
                end
                Gamestate.switch(fader)
            end },
            -- FIXME the execute doesn't seem to execute without this lmao
            { "...", speaker = 'chip' },
            { bail = true },

            { label = 'second time' },
            { "Huh. Hey, Chip. Do you have any idea what's in there?", speaker = 'kidneon' },
            { "DIRT. ROCKS. ETC. ETC.", speaker = 'chip' },
            { "NOTHING IMPORTANT.", speaker = 'chip' },
            {
                "Let's see about that...",
                "(You pry the door open. It's a solid dirt wall.)",
                "Guess so.",
                "Boring.",
                speaker = 'kidneon',
            },
        }))
    end
end


local MouseAlert = actors_base.Actor:extend{
    name = 'mouse alert',
    sprite_name = 'mouse alert',
}

function MouseAlert:launch()
    worldscene:add_actor(Bunker(Vector(646, 714)))
    worldscene.fluct:to(self.pos, 4, { y = 0 })
        :oncomplete(function()
            worldscene:remove_actor(self)
        end)
end


local Twig = actors_base.Actor:extend{
    name = 'twig',
    sprite_name = 'twig',
    dialogue_position = 'right',
    dialogue_sprite_name = 'twig portrait',

    is_usable = true,
}

function Twig:init(...)
    Twig.__super.init(self, ...)
    self.sprite:set_facing_right(false)
end

function Twig:fly_away()
    -- No more dialogue!
    self.is_usable = false
    worldscene.tick:delay(function()
        self.sprite:set_facing_right(true)
    end, 0.5)
    :after(function()
        local goal = self.ptrs.ship.pos
        local x0, y0 = self.pos:unpack()
        local x1, y1 = goal:unpack()
        local h = y0 - 64
        -- DON'T EVEN ASK
        local y0d, y1d = y0 - h, y1 - h
        local s = math.sqrt(y0d * y1d)
        local d = (x1 - x0) * (x1 - x0)
        local a = (2 * s + y1d + y0d) / d
        local b = -2 * (x0 * (s + y1d) + x1 * (s + y0d)) / d
        local c = h + b * b / (4 * a)
        worldscene.fluct:to(self.pos, 1, { x = goal.x })
            :onupdate(function()
                local x = self.pos.x
                self.pos.y = a * x * x + b * x + c
            end)
            :oncomplete(function()
                self.ptrs.ship:launch()
                worldscene:remove_actor(self)
            end)
    end, 0.5)
end

function Twig:on_use(activator)
    if activator.is_player then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = activator,
            chip = activator.ptrs.chip,
            twig = self,
        }, {
            -- Script
            -- First time
            { jump = 'second time', condition = 'spoken to twig' },
            { set = 'spoken to twig' },
            { "Greetings. ", speaker = 'kidneon' },
            { "...", speaker = 'twig' },
            { "Is this your ship? ", speaker = 'kidneon' },
            { "...", speaker = 'twig' },
            { "It's blocking what looks to be a... bunker? Or something. Do you know what's in there?", speaker = 'kidneon' },
            { "You've no permission to speak with me, subject. ", speaker = 'twig' },
            { "What?", speaker = 'kidneon' },
            { "...", speaker = 'twig' },
            { "Fine. Chip, can you perform a scan to see what's down there?", speaker = 'kidneon' },
            { "ALREADY DID. THERE IS NOTHING.", speaker = 'chip' },
            { "What, like we'd open it up and there'd be a wall? Or just dirt? Or what?", speaker = 'kidneon' },
            { "...YES. DIRT. ETC. ETC.", speaker = 'chip' },
            { "Oh, come on. The curiosity's killing me.", speaker = 'kidneon' },
            { "THERE IS NOTHING.", speaker = 'chip' },
            { "We'll see about that.", speaker = 'kidneon' },
            { bail = true },

            -- (Subsequent times before meeting talking requirements)
            { label = 'second time' },
            { jump = 'offer to fix the ship', condition = 'pearl: seen fixing the ship' },
            { "Seriously though, do you know anything about that bunker?", speaker = 'kidneon' },
            { "...", speaker = 'twig' },
            { "Hellooo?", speaker = 'kidneon' },
            { "(The cat's motionless. You're not sure whether they're sleeping or ignoring you.)", speaker = 'kidneon' },
            { bail = true },

            -- (Talk to twig before getting all the items you need, but after the reveal that the ship can be fixed via the pearl convo)
            { label = 'offer to fix the ship' },
            { jump = 'just fix the ship', condition = function()
                return game.progress.flags['got battery']
                    and game.progress.flags['got joystick']
                    and game.progress.flags['got nectar']
                    and game.progress.flags['got vacuum']
            end },
            { "Fixing the ship would be trivial for me.", speaker = 'kidneon' },
            { "...", speaker = 'twig' },
            { "Just saying.", speaker = 'kidneon' },
            { "...", speaker = 'twig' },
            { "In case that interests you.", speaker = 'kidneon' },
            { "(The cat's motionless. You're not sure whether they're sleeping or ignoring you.)", speaker = 'kidneon' },
            { bail = true },

            -- (Talk to twig after getting all the items you need, and after the reveal in the pearl convo)
            { label = 'just fix the ship' },
            { set = 'fixed the ship' },
            {
                "You know what? This ship is archaic, so I think I've actually got everything I'd need to fix it up.",
                "I can use the joystick to fix the control panel...",
                "The battery as the main power source...",
                "The vacuum to fix some of the propulsion setup...",
                "And the rocket fuel-- I mean, the flower nectar.",
                "Perfect.",
                "It shouldn't take me more than a few minutes to install everything. C'mon Chip, lend me a hand. Er, booster. Whatever.",
                speaker = 'kidneon',
            },
            { "I'D RATHER NOT.", speaker = 'chip' },
            { "Chip...", speaker = 'kidneon' },
            { "FINE.", speaker = 'chip' },
            {
                -- Fade out and back in to a fixed ship
                execute = function()
                    local sfx = game.resource_manager:get('assets/sounds/shipfix.ogg')
                    sfx:play()
                    -- TODO doesn't really matter, but, this doesn't seem to
                    -- happen at all if this execute is the first step?
                    Gamestate.push(SceneFader(Gamestate.current(), true, sfx:getDuration() / 2, {0, 0, 0}, function()
                        local ship = _find_actor_by_type_name('mouse alert')
                        if ship then
                            self.ptrs.ship = ship
                            ship.sprite:set_pose('fixed')
                        end
                        -- Update world in-place so the ship's new sprite shows up
                        worldscene:update(0)
                    end))
                end
            },
            { "There. Will you move it now, Twig? I'd honestly rather not spend any more time on this, but if it comes down to it, I'll be forced to hack in and--", speaker = 'kidneon' },
            { "Oh...", "My dream has come true? The divine God has answered my prayers?", speaker = 'twig' },
            {
                "What? No! It was me. I fixed it. No god.",
                "Listen. I'd really appreciate if you just moved this heap of junk already.",
                speaker = 'kidneon',
            },
            {
                "Yes! Truly, the divine God has indeed answered my prayers.",
                "The ship...",
                "The ship is finally... ",
                "Yes. Yes!",
                "I can finally free my brethren!",
                "I've long dreamt of this day, but thought it never to come.",
                "Freedom, at last, from our great bondage.",
                "May you be handsomely rewarded in Heaven, subject.",
                speaker = 'twig',
            },
            { "Moving the ship is reward enough for me, actually. Thanks.", speaker = 'kidneon' },
            { execute = function() self:fly_away() end },
        }))
    end
end


-- Doesn't actually do anything; just needs to be an actor to be animated
local AnisePlatform = actors_base.Actor:extend{
    name = 'anise platform',
    sprite_name = 'anise platform',
}

function AnisePlatform:blocks()
    return true
end


local Anise = actors_base.Actor:extend{
    name = 'anise',
    sprite_name = 'anise',
    dialogue_position = 'right',
    dialogue_sprite_name = 'anise portrait',

    is_usable = true,
    has_moved = false,
    clip_top = 0,
    clip_bottom = 0,
}

function Anise:move_to_stall()
    if self.has_moved then
        return
    end
    self.has_moved = true
    self.is_usable = false

    game.resource_manager:get('assets/sounds/bellting.ogg'):play()
    local x0, y0, x1, y1 = self.shape:bbox()
    worldscene.fluct:to(self, 0.25, { clip_top = y1 - y0 })
        :oncomplete(function()
            self:move_to(Vector(284, 1414))
            self.clip_bottom = 5
        end)
        :after(0.5, { clip_top = 0 })
        :oncomplete(function()
            self.is_usable = true
        end)
end

function Anise:draw()
    if self.clip_top == 0 and self.clip_bottom == 0 then
        Anise.__super.draw(self)
    else
        love.graphics.push('all')
        local x0, y0, x1, y1 = self.shape:bbox()
        local w = x1 - x0
        local h = y1 - y0
        local clip_top = math.floor(self.clip_top)
        love.graphics.setScissor(x0 - worldscene.camera.x, y0 + clip_top - worldscene.camera.y, w, math.max(0, h - clip_top - self.clip_bottom))
        self.sprite:draw_at(self.pos + Vector(0, self.clip_top))
        love.graphics.pop()
    end
end

function Anise:wrong_bell(activator)
    -- Called when the player rings the big bell instead of the little one
    game.resource_manager:get('assets/sounds/bellting.ogg'):play()
    Gamestate.push(DialogueScene({
        -- Speakers
        kidneon = activator,
        chip = activator.ptrs.chip,
        anise = self,
    }, {
        { jump = 'already here', condition = function() return self.has_moved end },
        { "NOT THAT BELL!!  THAT'S JUST FOR ME!!!", speaker = 'anise' },
        { bail = true },

        { label = 'already here' },
        { "I'm already here!!  Please stop ringing my precious bells!!!", speaker = 'anise' },
    }))
end

function Anise:on_use(activator)
    if activator.is_player then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = activator,
            chip = activator.ptrs.chip,
            anise = self,
        }, {
            -- Too early
            { jump = 'ring bell', condition = function() return self.has_moved end },
            { "AOWWRR!!!  I'M VERY BUSY!!!!  PLEASE RING THE BELL IF YOU NEED ASSISTANCE!!", speaker = 'anise' },
            { bail = true },

            -- Ring the bell
            { label = 'ring bell' },
            { jump = 'out of items', condition = 'anise: weird rectangle' },
            { "HI WELCOME TO STAR SHOP ANISE!!!!!!!! REOWOW!!! I'M STAR ANISE AND THESE DEALS CAN'T BE BEAT!!!!!", speaker = 'anise' },
            { "Is all of this stuff for sale?", speaker = 'kidneon' },
            { "Yes.", speaker = 'anise' },
            { "Cool.", speaker = 'kidneon' },
            {
                label = 'buying options',
                speaker = 'anise',
                menu = {
                    { 'ringy bell', "ringy bell - makes a cool noise when I bat it" },
                    { 'broken star', "broken star - makes a cool noise when I bat it" },
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
                    { 'nevermind', "nothing - the worst??  doesn't taste OR sound good" },
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
            { "No. Trust me. I've been trying to break it for ages, buddy. I've got a Space PhD in reverse engineering and even ~I~ can't figure this thing out.... Doesn't even make a good noise when you hit it! It's useless, by any metric.", speaker = 'anise' },
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
            { execute = function() worldscene:add_actor(MemoKey(Vector(258, 1424), { ['script name'] = 'anise' })) end },
            { bail = true },

            -- (after all items are checked and you get the memo key and talk to anise)
            { label = 'out of items' },
            { "Hey--", speaker = 'kidneon' },
            { "WE'RE OUT OF BUSINESS!!!! AOORWWW!!! CAN'T YOU READ????", speaker = 'anise' },
            { "(You look at the note the cat placed on the counter earlier. It's just a scrap of paper with a dirty pawprint on it.)", speaker = 'anise' },
            { bail = true },

            { label = 'nevermind' },
            { "Hmm.  I guess I don't need any of this.", speaker = 'kidneon' },
            { "Wh...  what?", speaker = 'anise' },
            { "What?", speaker = 'kidneon' },
            { "I'm afraid I don't understand.", speaker = 'anise' },
            { "I don't want anything.", speaker = 'kidneon' },
            { "Yes.  That's what I don't understand.", speaker = 'anise' },
        }))
    end
end


local Purrl = actors_base.Actor:extend{
    name = 'purrl',
    sprite_name = 'purrl',
    dialogue_position = 'right',
    dialogue_sprite_name = 'purrl portrait',

    is_usable = true,
}

function Purrl:on_use(activator)
    if activator.is_player then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = activator,
            chip = activator.ptrs.chip,
            purrl = self,
        }, {
            { jump = 'greeting2', condition = 'pearl: spoken once' },
            { set = 'pearl: spoken once' },
            { "Greetings. ", speaker = 'kidneon' },
            { "Mewooo! Hi! I'm Purrl! Who are you!", speaker = 'purrl' },
            { "You can call me Neon. Kid Neon.", speaker = 'kidneon' },
            { "Kid Mweeoow! I like it!", speaker = 'purrl' },
            { "...thanks.", speaker = 'kidneon' },
            { "Do you mind if I ask you a few questions?", speaker = 'kidneon' },
            { "Nyope!", speaker = 'purrl' },
            { jump = 'menu' },

            -- (if you talk to pearl again, new greet message)
            { label = 'greeting2' },
            { "Hi Kid Mewo!", speaker = 'purrl' },
            { "Hey Purrl.", speaker = 'purrl' },

            {
                label = 'menu',
                speaker = 'kidneon',
                menu = {
                    { 'living situation', "Living situation?", condition = function()
                        return not game.progress.flags['pearl: seen living situation']
                            and not game.progress.flags['pearl: seen living situation 2']
                    end},
                    { 'living situation 2', "Species?", condition = function()
                        return game.progress.flags['pearl: seen living situation']
                            and not game.progress.flags['pearl: seen living situation 2']
                    end},
                    { 'living situation 3', "Lunekos?", condition = function()
                        return game.progress.flags['pearl: seen living situation']
                            and game.progress.flags['pearl: seen living situation 2']
                    end},
                    { 'fish', "Fish?", condition = function() return not game.progress.flags['pearl: seen fish'] end },
                    { 'fish 2', "Fish...?", condition = function() return game.progress.flags['pearl: seen fish'] end },
                    {
                        'cat talking permissions',
                        "Twig... the cat near the spaceship?",
                        condition = function()
                            return game.progress.flags['spoken to twig']
                                and game.progress.flags['pearl: seen living situation 2']
                                and not game.progress.flags['pearl: seen cat talking permissions']
                                and not game.progress.flags['pearl: seen fixing the ship']
                        end,
                    },
                    {
                        'fixing the ship',
                        "Fixing the ship?",
                        condition = function()
                            return game.progress.flags['pearl: seen cat talking permissions']
                                and not game.progress.flags['pearl: seen fixing the ship']
                        end,
                    },
                    {
                        'items needed',
                        "Items needed to fix the ship?",
                        condition = function()
                            return game.progress.flags['pearl: seen cat talking permissions']
                                and game.progress.flags['pearl: seen fixing the ship']
                        end,
                    },
                    { 'nevermind', "Nevermind" },
                },

            },

            -- (1 - Living situation?)
            { label = 'living situation' },
            { set = 'pearl: seen living situation' },
            { "Do you live here?", speaker = 'kidneon' },
            { "Mweeooo! I do now! There was a free house here, so I made it mine. ", speaker = 'purrl' },
            { "I can't believe no one taked it already! Mewoo!", speaker = 'purrl' },
            { "Uh. Might be because of the many concentrated toxins in the air and the ground in this sector.", speaker = 'kidneon' },
            { "Oh! No wonder everyone's leaved me alone! It's purrlfect!", speaker = 'purrl' },
            { "...", speaker = 'kidneon' },
            { jump = 'menu' },

            -- (1a - Species? Living situation? )
            { label = 'living situation 2' },
            { set = 'pearl: seen living situation 2' },
            { "All right, look. I've never seen a species quite like you. Before today, I mean. If you're not from here, then can I ask where you ARE from? None of my wikkying is turning anything up, and it's been driving me up the wall.", speaker = 'kidneon' },
            { "I'm from the moon!", speaker = 'purrl' },
            { "You -- what. You're what? What?", speaker = 'kidneon' },
            { "We all got real tired of the systemic oppression lunekos face on Lil Luna, so me and my uncle Twig got a couple of our friends, banded together, and escaped! Now we're space rebels. Mweooo!", speaker = 'purrl' },
            { "...I... want... no, I NEED... to know... more... about...", speaker = 'kidneon' },
            { "A FULL INVESTIGATION OF LUNEKOS ESTIMATED TO TAKE SEVERAL DAYS. UNWISE USAGE OF TIME, AS THE NEXT FREQUENCY SHIFT IS--", speaker = 'chip' },
            { "I know, I know... Damn it! Maybe later.", speaker = 'kidneon' },
            { "One day, we'll free the lunekos... but first we need a colony here. Mweow.", speaker = 'purrl' },
            { "(Your curiosity is burning, but you're crunched for time.)", speaker = 'kidneon' },
            { jump = 'menu' },

            -- (1b - Lunekos?)
            { label = 'living situation 3' },
            { "(No. I can't go down this rabbit hole. ...cat hole. Whatever. If I start asking questions about a mysterious moon cat rebellion, I'll never be able to stop.)", speaker = 'kidneon' },
            { "Myewow!", speaker = 'purrl' },
            { jump = 'menu' },

            -- (2 - Fish?)
            { label = 'fish' },
            { set = 'pearl: seen fish' },
            { "Is that... a fish?", speaker = 'kidneon' },
            { "Huh? What's a fish?", speaker = 'purrl' },
            { "In your helmet. That thing swimming around... looks like a fish.", speaker = 'kidneon' },
            { "Oh, mewoo! No, silly! It's not a fish. It's a space fish!", speaker = 'purrl' },
            { "Morsel goes with me everywhere.", speaker = 'purrl' },
            { "\"Morsel\"?", speaker = 'kidneon' },
            { "Mweoo! A shorthand for M.O.R.S.E.L.! Mewoo!", speaker = 'purrl' },
            { "...what does it stand for?", speaker = 'kidneon' },
            { "Most Ordained Reverent Savior Everyone Loves! Morsel took out an entire army by itself! Meewoo!", speaker = 'purrl' },
            { "BZZT. NEON. DO YOU REMEMBER THE ORIGIN OF MY NAME?", speaker = 'chip' },
            { "It's just an uninspired reference to a computer chip.", speaker = 'kidneon' },
            { "WRONG. YOU TRIED TO TAKE A BITE OUT OF MY BOOSTER AND CHIPPED YOUR TOOTH.", speaker = 'chip' },
            { "What.", speaker = 'kidneon' },
            { jump = 'menu' },

            -- (2a Fish...?)
            { label = 'fish 2' },
            { "That's still a cool fish.", speaker = 'kidneon' },
            { "I mean, space fish. A cool space fish.", speaker = 'kidneon' },
            { "Mweeoo!! Morsel says thank you!", speaker = 'purrl' },
            { "(You think about Chip. The materials that make up their body are, in fact, very rare... and if you were to find and eat edible scraps of the same material, they'd probably grow out from your body in a uniquely useful way. Oh well. Maybe one day.)", speaker = 'kidneon' },
            { "BZZT... DON'T GET ANY FUNNY IDEAS, NEON.", speaker = 'chip' },
            { "Me? Never.", speaker = 'kidneon' },
            { jump = 'menu' },

            -- ( 4- Cat talking permissions?)
            { label = 'cat talking permissions' },
            { set = 'pearl: seen cat talking permissions' },
            { "Myep! My uncle, Branch Commander Twig!", speaker = 'purrl' },
            { "Do you have any idea what kind of permission I need in order to get him to speak with me? ", speaker = 'kidneon' },
            { "He just says that to anyone he thinks is annoying.", speaker = 'purrl' },
            { "...", speaker = 'kidneon' },
            { "Well. Do you know about his ship? And the bunker-looking structure beneath it? I couldn't get any info out of him, but it sure looks important.", speaker = 'kidneon' },
            { "Meeowow! The ship is the S.S. Mouse Alert! We crash landed here a long time ago. ", speaker = 'purrl' },
            { "Oh, gee whiz.. How'd you pull that off?", speaker = 'kidneon' },
            { "Mewo... turned out none of us ever learned how to land the ship. Mwoeow! Now it's all broke, so we can't go back and get more cats.", speaker = 'purrl' },
            { "Ah... that's unfortunate. So you've never been in that bunker, I take it?", speaker = 'kidneon' },
            { "Nyope!", speaker = 'purrl' },
            { "Bummer.", speaker = 'kidneon' },
            { jump = 'menu' },

            -- (4a - Fixing the ship?)
            { label = 'fixing the ship' },
            { set = 'pearl: seen fixing the ship' },
            { "You don't look that busy. Has everyone given up on the ship?", speaker = 'kidneon' },
            { "Myeowow... fixing things is hard and boring... breaking things is way more fun.", speaker = 'purrl' },
            { "I don't think it'd take that much effort to repair it, honestly.", speaker = 'kidneon' },
            { "BZZT. CURSORY SCAN PERFORMED EARLIER ON THE S.S. MOUSE ALERT AT THE CRASH SITE INDICATED MISSING ITEMS TO BE: STEERING CONTROL PANEL, VACUUMING DEVICE, PORTABLE BATTERY CELL, AND FUEL.", speaker = 'chip' },
            { "That's extremely manageable. There are plenty of scraps around here. I'm sure with some creativity, you'd be able to make do.", speaker = 'kidneon' },
            { "Meowow! But I don't want to go anywhere. This is my colony now! Mewow!", speaker = 'purrl' },
            { "But what about freeing the other lunekos?", speaker = 'kidneon' },
            { "That can wait. But you know what can't wait? Chasing tiny birds! Mewew!", speaker = 'purrl' },
            { "If I help fix the ship, will Twig move it?", speaker = 'kidneon' },
            { "I don't know! Or care! Mewoweow! ", speaker = 'purrl' },
            { "Go ask him yourself! Mewoo!", speaker = 'purrl' },
            { jump = 'menu' },

            -- (4b - Items needed to fix the ship?)
            { label = 'items needed' },
            { jump = 'got everything', condition = function()
                return game.progress.flags['got battery']
                    and game.progress.flags['got joystick']
                    and game.progress.flags['got nectar']
                    and game.progress.flags['got vacuum']
            end },
            { "(Chip said I needed... a steering control panel, a vacuuming device, a battery cell, and fuel. Surely I can find some close stand-ins if I look around.)", speaker = 'kidneon' },
            { jump = 'menu' },

            -- if you have everything
            { label = 'got everything' },
            { "(I got everything.)", speaker = 'kidneon' },
            { jump = 'menu' },

            { label = 'nevermind' },
            { "Actually, nevermind. See you around.", speaker = 'kidneon' },
            { "Mweeo!", speaker = 'purrl' },
        }))
    end
end


local NyapoIon = actors_base.Actor:extend{
    name = 'nyapo-ion',
    sprite_name = 'nyapo-ion',
    dialogue_position = 'right',
    dialogue_sprite_name = 'nyapo-ion portrait',

    is_usable = true,
}

function NyapoIon:on_use(activator)
    if activator.is_player then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = activator,
            chip = activator.ptrs.chip,
            nyapoion = self,
        }, {
            { jump = 'convo 2', condition = 'spoken to nyapo-ion' },
            { set = 'spoken to nyapo-ion' },
            { "Oh, thank the stars. You're finally here.", speaker = 'nyapoion' },
            { "Me?", speaker = 'kidneon' },
            {
                "Yes. You.",
                "I've been stuck waiting here for a long time.",
                "Hey. Wait. Where's... the pizza?",
                speaker = 'nyapoion',
            },
            { "Er. Pizza?", speaker = 'kidneon' },
            { "Oh, my dog. How can you forget the one thing I ordered? I asked you to get me a pizza when you left.", speaker = 'nyapoion' },
            { "Do you have any idea how long I've been waiting...?", speaker = 'nyapoion' },
            { "I think you might be mixing me up for someone else.", speaker = 'kidneon' },
            {
                "Nope. There's no way.",
                "Pinkurple suit... Fashionably random lights... annoying voice... a tiny robotic cat...",
                "I could never forget the galactic pizza warrior!",
                "\"Don't worry, Nyapo-Ion! I'll get you your pizza!\"",
                "Well, where is it?",
                "Where's the PIZZA?",
                speaker = 'nyapoion',
            },
            { "I think you might be definitely mixing me up for someone else. ", speaker = 'kidneon' },
            { "Yeah right. Unless your tiny cat's NOT named Chip.", speaker = 'nyapoion' },
            { "...Ha ha. Chip's not a particularly inspired name. Lucky guess.", speaker = 'kidneon' },
            { "PROBABILITY OF LUCKY GUESS AT LESS THAN ONE IN ONE BILLION.", speaker = 'chip' },
            { "What? That can't be right. There aren't even anywhere NEAR close to that many words in all the languages of--", speaker = 'kidneon' },
            { "I'VE SHARED A MUSIC FILE FROM MY DEEPEST STORAGE WITH YOU.", speaker = 'chip' },
            {
                "What?",
                "...",
                "galacticpizzawarrior.smpl?",
                "Chip.",
                speaker = 'kidneon',
            },
            { "NEON.", speaker = 'chip' },
            { "Where did this come from.", speaker = 'kidneon' },
            { "YOU-", speaker = 'chip' },
            { "ACTUALLY, ", speaker = 'kidneon' },
            { "Nevermind. I don't want to know.", speaker = 'kidneon' },
            { "(The disgruntled cat mumbles something about not tipping you, and then stares at the corner of the room.)", speaker = 'kidneon' },
            { bail = true },
        
            -- (talk again without old pizza box)
            { label = 'convo 2' },
            { jump = 'found pizza', condition = 'got pizza box' },
            { "If you don't have my hecking pizza, then just... just leave me alone...", speaker = 'nyapoion' },
            { "(They're just staring off into a corner. I don't have anything for them...)", speaker = 'kidneon' },
            { execute = function() game.resource_manager:get('assets/sounds/pizzachip.ogg'):play() end },
            { "PLAYING INSPIRATIONAL CLIP.", speaker = 'chip' },
            { "...Chip.", speaker = 'kidneon' },
            { "NEON.", speaker = 'chip' },
            { "Delete that.", speaker = 'kidneon' },
            { "YOU CAN'T DELETE THE PAST, NEON.", speaker = 'chip' },
            { "That's never going to stop me from trying.", speaker = 'kidneon' },
            { bail = true },

            -- (arrive to nyapo with the old pizza box)
            { label = 'found pizza' },
            { "Hey, I found out what happened to your pizza.", speaker = 'kidneon' },
            { "(You give the cat the empty box...)", speaker = 'kidneon' },
            { "Oh my dog! I knew you were lying!", speaker = 'nyapoion' },
            { "I'm not lying! It's... complicated. ", speaker = 'kidneon' },
            { "Simplified, you're just remembering a different reality from the one we live in.", speaker = 'kidneon' },
            { "Wow. And now you take me for a moron? To scam me out of a pizza?", speaker = 'nyapoion' },
            { "No! What I mean to say is: the galactic pizza warrior does NOT exist anymore, so you're better off forgetting about literally everything to do with it.", speaker = 'kidneon' },
            { "Forgetting about everything to do with what?", speaker = 'nyapoion' },
            { "Everything to do with...", speaker = 'kidneon' },
            { "Uh, don't worry about it. Enjoy your empty box.", speaker = 'kidneon' },
            { "Oh man, I can't wait to test drive this baby! Thanks!", speaker = 'nyapoion' },
            { "(The cat's already fast asleep on their new bed.)", speaker = 'kidneon' },
            { "All... right. ", speaker = 'kidneon' },
            { "Guess all's well that ends well, huh, Chip?", speaker = 'kidneon' },
            { execute = function() game.resource_manager:get('assets/sounds/pizzachip.ogg'):play() end },
            { "PLAYING INSPIRATIONAL CLIP.", speaker = 'chip' },
            { "I'm going to turn you off and punt you into the horizon.", speaker = 'kidneon' },
            {
                "BZZT. WRONG. I COULD OUTMATCH YOU IN ANY CONTEST OF SPEED OR WITS.",
                "YOUR ORGANIC BODY STANDS NO CHANCE.",
                "ESTIMATION AT 100% THAT I WOULD REMAIN BOTH ON AND UNPUNTED.",
                speaker = 'chip',
            },
            { "Hey, c'mon. I'm only MOSTLY organic. Toss me a percent or two.", speaker = 'kidneon' },
            { "BZZT. NAH.", speaker = 'chip' },
            -- FIXME seems like talking again should give a zzz
        }))
    end
end


local PizzaBox = actors_base.Actor:extend{
    name = 'pizza box',
    sprite_name = 'pizza box',

    is_usable = true,
}

function PizzaBox:on_use(activator)
    if activator.is_player then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = activator,
            chip = activator.ptrs.chip,
        }, {
            -- TEXT FOR PIZZA BOX outside nyapo's house if you try to pick it up without having talked to nyapo
            { jump = 'talked to nyapo', condition = 'spoken to nyapo-ion' },
            { set = 'saw pizza box early' },
            { "(It's a small, greasy box. Looks ancient. Has a galactic motif.\nSeems like I should pick it up, but I have no idea why I'd need something like this, so I won't.)", speaker = 'kidneon' },
            { bail = true },

            -- with having talked to nyapo, if you didn't check the box before talking to nyapo
            { label = 'talked to nyapo' },
            { jump = 'mild regret', condition = 'saw pizza box early' },
            { "(It's a small, greasy box. Looks ancient. Has a galactic motif.\nI think I have some idea what this is.)", speaker = 'kidneon' },
            { jump = 'pick up' },

            -- with having talked to Nyapo, if you checked the box before talking to nyapo
            { label = 'mild regret' },
            { "(Well. Guess I should've picked it up earlier.)", speaker = 'kidneon' },
            -- fallthrough
            { label = 'pick up' },
            { set = 'got pizza box' },
            { execute = function() worldscene:remove_actor(self) end },
        }))
    end
end

--------------------------------------------------------------------------------
-- Non-cats

local Nectar
local Iridd = actors_base.Actor:extend{
    name = 'iridd',
    sprite_name = 'iridd',
    dialogue_position = 'right',
    dialogue_sprite_name = 'iridd portrait',

    is_usable = true,
}

function Iridd:on_use(activator)
    if activator.is_player then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = activator,
            chip = activator.ptrs.chip,
            iridd = self,
        }, {
            { jump = 'after drop', condition = 'spoken to iridd' },
            { set = 'spoken to iridd' },
            { "Hello, hello! I'm Iridd. Welcome to my humble abode! What brings you here, stranger?", speaker = 'iridd' },
            { "Greetings. Just poking around. Looking for upgrades and scraps and keys and whatnot. That kind of thing.", speaker = 'kidneon' },
            { "Ah. Let me know if there's anything I can do, won't you?", speaker = 'iridd' },
            { "Sure.\nActually, are you native to this area?", speaker = 'kidneon' },
            { "Yes! I sprouted here long, long ago.", speaker = 'iridd' },
            { "I'm really curious about everything that thrives here without some kind of protection. For non-native life, long term exposure to this environment isn't usually conducive to... living. ", speaker = 'kidneon' },
            { "Ah, but that's what I like best about living here! I don't often have to look very far for quality food. ", speaker = 'iridd' },
            { "You... eat? ", speaker = 'kidneon' },
            { "Yes! Tasty, tasty oil.", speaker = 'iridd' },
            { "Oh, I thought you were implying you ate carrion.", speaker = 'kidneon' },
            { "Yes! Everything that dies here ends up breaking down into oil. I like the fresh oil. The older stuff is really hard to sink my roots into, you know?", speaker = 'iridd' },
            { "...oh. ", speaker = 'kidneon' },
            { "Also, I make more nectar when I get to drink fresh from the source. Would you like some? I've plenty to spare.", speaker = 'iridd' },
            { "What, oil? No thanks.", speaker = 'kidneon' },
            {
                "No, nectar! Would you like some nectar?",
                "It's cherry flavor. And, ah! So tasty.",
                "So, so tasty. Mmm!",
                speaker = 'iridd',
            },
            { "Oh. Yeah, sure.", speaker = 'kidneon' },
            { execute = function() worldscene:add_actor(Nectar(Vector(1212, 1576))) end },
            { bail = true },

            -- (Talk again before picking the bottle up)
            { label = 'after drop' },
            { jump = 'got bottle', condition = 'got nectar' },
            { "Go on and drink up! It's all yours!", speaker = 'iridd' },
            { "Thanks.", speaker = 'kidneon' },
            { bail = true },

            -- (Talk again after picking the bottle up)
            { label = 'got bottle' },
            { "Are you thirsty yet?", speaker = 'iridd' },
            { "Nope. Still good.", speaker = 'kidneon' },
            {
                "Darn... maybe later!",
                "I really want to see...",
                "A gasp of surprise at your first sip...",
                "Flavor foam frothing up from your mouth...",
                "Your eyes rolling to the back of your head...",
                "Ah... ",
                "ah...",
                "Pure bliss.",
                "Don't forget to come back here if you drink it. Please?",
                speaker = 'iridd',
            },
            { "Sure.", speaker = 'kidneon' },
            { "(Chip floats uneasily nearby. Cute.)", speaker = 'kidneon' },
            { bail = true },
        }))
    end
end


Nectar = actors_base.Actor:extend{
    name = 'nectar',
    sprite_name = 'nectar',

    is_usable = true,
}

function Nectar:on_use(activator)
    if activator.is_player then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = activator,
            chip = activator.ptrs.chip,
            iridd = Iridd,
        }, {
            { "(This smells like...)", speaker = 'kidneon' },
            { "(BZZT. MAGICALLY-ENHANCED LIQUID HYDROGEN. WITH ALMOND EXTRACT.)", speaker = 'chip' },
            { "(Woooof! This is volatile stuff.)", speaker = 'kidneon' },
            { "(IMBIBING THE NECTAR EXPECTED TO PRODUCE LESS THAN DESIRABLE EFFECTS ON A SCRAPGOAT BODY.)", speaker = 'chip' },
            { "(Like, the \"will make me grow almond horns\" kind of less desirable effect? Or...)", speaker = 'kidneon' },
            { "(THE *MOST* LESS DESIRABLE EFFECT.)", speaker = 'chip' },
            { "Oh me, oh my! What are you waiting for?\nTake a sip!", speaker = 'iridd' },
            { "You know, I'm actually not super thirsty right now. I'll save it for later. Thanks.", speaker = 'kidneon' },
            { "Aw, shucks.\nYou should come back here when you're ready to try it. I'll give you as much as you like!", speaker = 'iridd' },
            { "Good to know.", speaker = 'kidneon' },
            { "(You carefully put the bottle away in one of your cloak's pockets as Iridd intently watches you.)", speaker = 'kidneon' },
            { set = 'got nectar' },
            { execute = function() worldscene:remove_actor(self) end },
        }))
    end
end


local RadioGoat = actors_base.Actor:extend{
    name = 'radio goat',
    sprite_name = 'radio goat',
    dialogue_position = 'right',
    dialogue_sprite_name = 'radio goat portrait',

    is_usable = true,
}

function RadioGoat:on_use(activator)
    if activator.is_player then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = activator,
            chip = activator.ptrs.chip,
            radiogoat = self,
        }, {
            { jump = 'second time', condition = 'spoken to radiogoat' },
            { set = 'spoken to radiogoat' },
            { "You! You're always following me around. What's the deal?", speaker = 'kidneon' },
            { "...", speaker = 'radiogoat' },
            { "The ol' silent shtick as usual, huh? ", speaker = 'kidneon' },
            { "Man. Do you even understand me? Are you even self-aware?", speaker = 'kidneon' },
            { "...", speaker = 'radiogoat' },
            { "BZZT... EXTRACTED AND UPDATED FREQUENCY SHIFT ESTIMATION DATA. NEXT FREQUENCY SHIFT EXPECTED TO OCCUR WITHIN THE DAY.", speaker = 'chip' },
            { "Guess we better hurry and get inside the main building as soon as possible. I don't think there's enough time to accurately determine if there are any outside safe zones in this sector... ", speaker = 'kidneon' },
            { "OR WHERE ANY OF THEM ARE WITH ANY REASONABLE CERTAINTY.", speaker = 'chip' },
            { "Right.", speaker = 'kidneon' },
            { bail = true },

            -- (Talk to radio goat again)
            { label = 'second time' },
            { "...", speaker = 'kidneon' },
            { "...", speaker = 'radiogoat' },
            { "NO NEW DATA TO BE EXTRACTED.", speaker = 'chip' },
            { "C'mon. Let's get a move on. Time's a-tickin'. ", speaker = 'kidneon' },
        }))
    end
end


local Battery
local Electroskunk = actors_base.Actor:extend{
    name = 'electroskunk',
    sprite_name = 'electroskunk 2',
    dialogue_position = 'right',
    dialogue_sprite_name = 'electroskunk 2 portrait',

    is_usable = true,
}

function Electroskunk:on_use(activator)
    if activator.is_player then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = activator,
            chip = activator.ptrs.chip,
            zap = self,
        }, {
            { jump = 'final', condition = 'spoken to zap again' },
            { jump = 'got battery', condition = 'got battery' },
            { jump = 'second time', condition = 'spoken to zap' },
            { set = 'spoken to zap' },
            { "Rraghh!!!", speaker = 'zap' },
            { "What? What's wrong?", speaker = 'kidneon' },
            { "I can't get all the stuff off this thing!", speaker = 'zap' },
            { "What? ", speaker = 'kidneon' },
            { "Here. Look for yourself.", speaker = 'zap' },
            { execute = function() worldscene:add_actor(Battery(Vector(824, 1803))) end },
            { bail = true },

            -- (When talking to squirrel before picking up battery)
            { label = 'second time' },
            { "I don't have it! It's right there!", speaker = 'zap' },
            { bail = true },

            -- (Talk to zap again)
            { label = 'got battery' },
            { set = 'spoken to zap again' },
            { "How's the nest coming along?", speaker = 'kidneon' },
            {
                "Good. I'm so happy this place opened up! Someone used to live here, but I noticed I hadn't seen them for a while, so I poked around and saw it was vacant again.",
                "It wasn't even that dirty, either. All I had to do was vacuum up some oil spots! Easy.",
                "You have no idea how happy my girlfriend's gonna be once she realizes we don't have to live in a puzzle zone anymore. Seriously.",
                speaker = 'zap',
            },
            { "Living in a puzzle zone doesn't sound that bad to me.", speaker = 'kidneon' },
            { "Man, you say that, but when you wake up at 2AM and you're not thinking straight and all you wanna do is go pee but the horizontal wire is missing and god who misplaced that son of a--", speaker = 'zap' },
            { "All right, yeah. Fair point.", speaker = 'kidneon' },
            {
                "Now imagine that, but with kids. ",
                "You'd be halfway to solving one puzzle and then you'd realize that actually they don't need to use the toilet anymore, but instead you have a whole 'nother kind of problem to solve.",
                "So just, nope. Ain't happening.",
                speaker = 'zap',
            },
            { "Extremely fair point.", speaker = 'kidneon' },
            { bail = true },

            -- Talk to Zap again
            { label = 'final' },
            { "(Seems like the nest is coming along just fine.)", speaker = 'kidneon' },
        }))
    end
end


Battery = actors_base.Actor:extend{
    name = 'battery pickup',
    sprite_name = 'battery pickup',

    is_usable = true,
}

function Battery:on_use(activator)
    if activator.is_player then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = activator,
            chip = activator.ptrs.chip,
            zap = Electroskunk,
        }, {
            { "(Looks like... all the wires connected to this battery have been heavily chewed.)", speaker = 'kidneon' },
            { "So, what? You wanted the wires removed?", speaker = 'kidneon' },
            { "Yes! ", speaker = 'zap' },
            { "All right. Chip?", speaker = 'kidneon' },
            { "BZZT. CHILD'S PLAY. ALREADY DONE.", speaker = 'chip' },
            { "Here you go. ", speaker = 'kidneon' },
            { "What, no! I don't want that trash! I just need the wires for my nest. I got skunklets on the way, and they gotta have a comfortable place to sleep.", speaker = 'zap' },
            { "Oh. Congrats?", speaker = 'kidneon' },
            { "Thanks.", speaker = 'zap' },
            { "Mind if I keep the battery?", speaker = 'kidneon' },
            { "Knock yourself out. ", speaker = 'zap' },
            { "(You store the battery in one of your cloak's pockets.)", speaker = 'kidneon' },
            { set = 'got battery' },
            { execute = function() worldscene:remove_actor(self) end },
        }))
    end
end


local Electroskunk2 = actors_base.Actor:extend{
    name = 'electroskunk 2',
    sprite_name = 'electroskunk',
    dialogue_position = 'right',
    dialogue_sprite_name = 'electroskunk portrait',

    is_usable = true,
}

function Electroskunk2:on_use(activator)
    if activator.is_player then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = activator,
            chip = activator.ptrs.chip,
            trixy = self,
        }, {
            { jump = 'second time', condition = 'spoken to trixy' },
            { set = 'spoken to trixy' },
            { "Ho hum! Who even designed this area? Why do I need to think about electrical wiring just to get to my house? Don't like it, not one bit. ", speaker = 'trixy' },
            { "Have you tried making notes? It's not that bad if you just pay attention to where the wiring goes.", speaker = 'kidneon' },
            { "Of course I tried that!", speaker = 'trixy' },
            { "But then I remembered that I can't read.", speaker = 'trixy' },
            { "You could draw a picture, then?", speaker = 'kidneon' },
            { "I can't. I used all my paper up on writing notes.", speaker = 'trixy' },
            { "That's a conundrum.", speaker = 'kidneon' },
            { "Sigh. At least I can glide around. My boyfriend can't, so he sometimes gets stuck until I help him up. Oh well. I don't know what I'm gonna do next month...", speaker = 'trixy' },
            { bail = true },

            -- (If you talk to Trixy again)
            { label = 'second time' },
            { "Auugghh! I hate puzzles!!! Why do they even exist?! Who made up puzzles?! I'll kick their ass!", speaker = 'trixy' },
            { "Truly a mystery.", speaker = 'kidneon' },
        }))
    end
end


local Smiley = actors_base.Actor:extend{
    name = 'smiley',
    sprite_name = 'smiley',
    dialogue_position = 'right',
    dialogue_sprite_name = 'smiley portrait',

    is_usable = true,
}

function Smiley:on_use(activator)
    if activator.is_player then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = activator,
            chip = activator.ptrs.chip,
            smiley = self,
        }, {
            { jump = 'second time', condition = 'spoken to smiley' },
            { set = 'spoken to smiley' },
            { "HELLO AGAIN, FRIEND.", speaker = 'smiley' },
            { "Hey. ", speaker = 'kidneon' },
            { "HELLO.", speaker = 'chip' },
            { "TAKING ANOTHER DIVE THROUGH THE YARD, EH?", speaker = 'smiley' },
            {
                "As usual.",
                "We're trying to get inside the building before the shift occurs. It'd be a lot easier if someone stopped changing up the passcodes and keys.",
                "You wouldn't happen to know anything about that, would you?",
                speaker = 'kidneon',
            },
            { "THAT IS NOT ONE OF MY FUNCTIONS, FRIEND. I SIMPLY REMAIN IN ALL SECTORS TO GREET ANY NEW VISITORS.", speaker = 'smiley' },
            { "Yeah. Sure. ", speaker = 'kidneon' },
            { "THIS IS A SCENIC SECTOR. I SINCERELY HOPE YOU TAKE THE TIME TO FULLY ENJOY ITS SIGHTS, FRIEND.", speaker = 'smiley' },
            { "I'll try. ", speaker = 'kidneon' },
            { "THAT IS ALL I CAN WISH FOR. HAVE A GOOD TIME LOOKING AROUND, FRIEND.", speaker = 'smiley' },
            { "See you around.", speaker = 'kidneon' },
            { bail = true },

            -- (talk to Smiley again)
            { label = 'second time' },
            { "HELLO AGAIN, FRIEND.", speaker = 'smiley' },
            { "Hey.", speaker = 'kidneon' },
            { "STILL ENJOYING THE YARD?", speaker = 'smiley' },
            { "As much as anyone can be said to enjoy it, yes. Thanks.", speaker = 'kidneon' },
            { "HAVE FUN EXPLORING, FRIEND.", speaker = 'smiley' },
        }))
    end
end


local Joystick
local StoplightCat = actors_base.Actor:extend{
    name = 'stoplight cat',
    sprite_name = 'stoplight cat',
    dialogue_position = 'right',
    dialogue_sprite_name = 'stoplight cat portrait',

    is_usable = true,
}

function StoplightCat:on_use(activator)
    if activator.is_player then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = activator,
            chip = activator.ptrs.chip,
            lumi = self,
        }, {
            { jump = 'second time', condition = 'spoken to lumi' },
            { set = 'spoken to lumi' },
            { "STOP! GO! BZZTMEOOOW!", speaker = 'lumi' },
            { "Greetings.", speaker = 'kidneon' },
            { "GO! STOP! SLOW! GO! GO! GO GO GO! MEEEOOWW!", speaker = 'lumi' },
            { "Hey, Chip. Do you know what this is?", speaker = 'kidneon' },
            { "BZZT. LOOKS LIKE AN UNFINISHED TRAFFIC COMPANION MODEL FROM CENTURIES AGO.", speaker = 'chip' },
            { "Whoa. Really? Do you have the specs on it?", speaker = 'kidneon' },
            { "YES. FOR BOTH THIS SPECIFIC ONE AND FOR THE FINISHED MODEL.", speaker = 'chip' },
            { "Could you share the files with me?", speaker = 'kidneon' },
            { "I SHARED THE FILES WITH YOU THE MOMENT I PICKED IT UP ON MY RADAR. BZZT. PLEASE TRY TO KEEP UP.", speaker = 'chip' },
            { "Thanks, Chip. Can't wait to take a look. Maybe I can trade you in for a model a little closer to my speed...", speaker = 'kidneon' },
            { "MEEOOOWW!!! BZZZZT! GO GO GOOO STOP! STOP!", speaker = 'lumi' },
            { "BZZT. DELETING FRIENDSHIP.", speaker = 'chip' },
            { "Don't do that! I need our friendship file intact so I can install it in your successor.", speaker = 'kidneon' },
            { "BZZT. I WOULD LAUNCH YOU INTO THE SUN BEFORE I WOULD CONSIDER ALLOWING THAT.", speaker = 'chip' },
            { execute = function() worldscene:add_actor(Joystick(Vector(720, 1330))) end },
            { bail = true },

            -- Talk to Lumi again
            { label = 'second time' },
            { "MEOOOOW! STOP! GO! STOP! MEOW! CROSSWALK BLINK MEOW!", speaker = 'lumi' },
            { "(Wow... what a cool cat... If only I had a companion this impressive...)", speaker = 'kidneon' },
            { "(BZZT. GO FROM ME, NEON.)", speaker = 'chip' },
        }))
    end
end


Joystick = actors_base.Actor:extend{
    name = 'joystick',
    sprite_name = 'joystick',

    is_usable = true,
}

function Joystick:on_use(activator)
    if activator.is_player then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = activator,
            chip = activator.ptrs.chip,
        }, {
            { "Oh geez... this thing looks like something I'd see in a retro arcade. How'd this defunct Lumi model end up carrying it? ", speaker = 'kidneon' },
            { "SOMEONE DISCARDED IT.", speaker = 'chip' },
            { "Wow. Thanks for your amazing insight, Chip.", speaker = 'kidneon' },
            { "NO PROBLEM. BZZT. JUST GIVING YOU A PREVIEW OF YOUR LIFE WITH A DIFFERENT COMPANION CAT MODEL.", speaker = 'chip' },
            { "Nice. I like it. I'll get to look smarter by comparison, for once.", speaker = 'kidneon' },
            {
                "BZZT. IS THAT WHAT YOU WANTED? PLEASE HOLD. I PREVIOUSLY DEMONSTRATED THE WRONG PERSONALITY TEMPLATE TO FIT THAT CRITERIA.",
                "UPDATING PREVIEW.",
                "MEOW STOP GO STOP MEOW.",
                "PREVIEW COMPLETE.",
                speaker = 'chip',
            },
            { "You know, on second thought, I'll keep you around. Your meow's pretty good, and that's really the only standard I've been going by.", speaker = 'kidneon' },
            { "BUT I'M ALSO CUTER.", speaker = 'chip' },
            { "That too.", speaker = 'kidneon' },
            { set = 'got joystick' },
            { execute = function() worldscene:remove_actor(self) end },
        }))
    end
end


Vacuum = actors_base.Actor:extend{
    name = 'vacuum',
    sprite_name = 'vacuum',

    is_usable = true,
}

function Vacuum:on_use(activator)
    if activator.is_player then
        Gamestate.push(DialogueScene({
            -- Speakers
            kidneon = activator,
            chip = activator.ptrs.chip,
        }, {
            { "Whoa. Looks like an old-timey handheld vacuum cleaner. This model is seriously ancient. Might be useful.", speaker = 'kidneon' },
            { "(You store the vacuum in one of your cloak's pockets.)", speaker = 'kidneon' },
            { set = 'got vacuum' },
            { execute = function() worldscene:remove_actor(self) end },
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


return {
    MagnetGoat = MagnetGoat,
}
