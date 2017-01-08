local Class = require 'vendor.hump.class'
local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local BaseScene = require 'isaacsdescent.scenes.base'

local SPEAKER_SCALE = 4
local SCROLL_RATE = 64  -- characters per second

-- Magic rendering numbers
local HORIZ_TEXT_MARGIN = 32

local DialogueScene = Class{
    __includes = BaseScene,
    __tostring = function(self) return "dialoguescene" end,
}

-- TODO as with DeadScene, it would be nice if i could formally eat keyboard input
function DialogueScene:init(wrapped)
    BaseScene.init(self)

    self.wrapped = wrapped

    -- TODO a good start, but
    self.speakers = {
        isaac = {
            sprite = game.sprites.isaac_dialogue:instantiate(),
            background = dialogueboximg,
            mood = 'default',
        },
        lexy = {
            sprite = game.sprites.lexy_dialogue:instantiate(),
            background = dialogueboximg2,
            mood = 'default',
        },
    }
    self.speakers.isaac.sprite:set_scale(SPEAKER_SCALE)
    self.speakers.lexy.sprite:set_scale(SPEAKER_SCALE)
    -- TODO temporary
    self.script = {
        -- TODO æons  :(
        --{ "I would wager no one has set foot in these caves in eons.  It's a miracle any of these mechanisms still work." },
        { "Remind me why the greatest wizard on Owel can't just teleport to the end of the cave?  Or drink a walk through walls potion?", speaker='lexy' },
        { "An excellent and perceptive question, fox.  Well done.", speaker='isaac' },
        { "It's not that simple, because...", speaker='isaac' },
        { nil, speaker='lexy', mood='yeahsure' },
        { "Hmm, how do I put this...", speaker='isaac' },
        { "The entire cavern has been...  enchanted with...  an anti-cheating field.  Quite common in these sorts of places, unfortunately for us.", speaker='isaac' },
        { "Damn!  And here cheating is my favorite thing.  How did they know?", speaker='lexy' },
    }
    -- TODO should rig up a whole thing for who to display and where, pose to use, etc., but for now these bits are hardcoded i guess
    self.font = m5x7  -- TODO global, should use resourcemanager probably
    
    -- State of the current phrase
    self.curline = 1
    self.curchar = 0
    self.phrase_lines = nil  -- set below
    self.phrase_speaker = nil
    self.phrase_timer = nil  -- counts in time * SCROLL_RATE; every time it goes up by 1, a new character should appear

    self.state = 'start'

    -- TODO magic numbers
    self.wraplimit = love.graphics.getWidth() - HORIZ_TEXT_MARGIN * 2

    self.script_index = 0
end

function DialogueScene:update(dt)
    for _, speaker in pairs(self.speakers) do
        speaker.sprite:update(dt)
    end

    while self.state == 'start' or (self.state == 'waiting' and love.keyboard.isDown('space')) do
        if self.script_index >= #self.script then
            -- TODO actually not sure what should happen here
            self.state = 'done'
            return
        end
        self.script_index = self.script_index + 1
        local step = self.script[self.script_index]

        if step[1] then
            self.state = 'speaking'
            local _textwidth
            _textwidth, self.phrase_lines = self.font:getWrap(step[1], self.wraplimit)
            self.phrase_speaker = self.speakers[step.speaker]
            -- TODO euugh.  not only is this gross, it's wrong, because isaac faces left in this sprite
            self.phrase_speaker.sprite:set_pose(self.phrase_speaker.mood .. '/talk/right')
            self.phrase_timer = 0
            self.curline = 1
            self.curchar = 0
        else
            -- Textless steps are commands
            -- TODO this is super hokey at the moment dang
            self.speakers[step.speaker].mood = step.mood
            self.speakers[step.speaker].sprite:set_pose(step.mood .. '/right')
        end
    end

    if self.state == 'speaking' then
        self.phrase_timer = self.phrase_timer + dt * SCROLL_RATE
        -- Show as many new characters as necessary, based on time elapsed
        while self.phrase_timer >= 1 do
            -- Advance cursor, continuing across lines if necessary
            self.curchar = self.curchar + 1
            if self.curchar > string.len(self.phrase_lines[self.curline]) then
                if self.curline == #self.phrase_lines then
                    self.state = 'waiting'
                    self.phrase_speaker.sprite:set_pose(self.phrase_speaker.mood .. '/right')
                    break
                else
                    self.curline = self.curline + 1
                    self.curchar = 0
                end
            end
            -- Count a non-whitespace character against the timer
            if string.sub(self.phrase_lines[self.curline], self.curchar, self.curchar) ~= " " then
                self.phrase_timer = self.phrase_timer - 1
            end
        end
    end
end

function DialogueScene:draw()
    -- TODO this bit is copied from DeadScene
    self.wrapped:draw()
    love.graphics.setColor(0, 0, 0, 64)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getDimensions())
    love.graphics.setColor(255, 255, 255)

    -- Draw the dialogue box, which is slightly complicated because it involves
    -- drawing the ends and then repeating the middle bit to fit the screen
    -- size
    -- TODO this feels rather hardcoded
    local boxheight = 160
    local boxwidth = love.graphics.getWidth()
    local boxtop = love.graphics.getHeight() - boxheight

    local background = self.phrase_speaker.background
    local boxrepeatleft, boxrepeatright = 192, 224
    local boxquadl = love.graphics.newQuad(0, 0, boxrepeatleft, background:getHeight(), background:getDimensions())
    love.graphics.draw(background, boxquadl, 0, boxtop, 0, 2)
    local boxquadm = love.graphics.newQuad(boxrepeatleft, 0, boxrepeatright - boxrepeatleft, background:getHeight(), background:getDimensions())
    love.graphics.draw(background, boxquadm, boxrepeatleft * 2, boxtop, 0, math.floor(love.graphics.getWidth() / (boxrepeatright - boxrepeatleft)) + 1, 2)
    local boxquadr = love.graphics.newQuad(boxrepeatright, 0, background:getWidth() - boxrepeatright, background:getHeight(), background:getDimensions())
    love.graphics.draw(background, boxquadr, love.graphics.getWidth() - (background:getWidth() - boxrepeatright) * 2, boxtop, 0, 2)

    -- Compute the text we should be displaying so far
    -- TODO it bugs me slightly that we re-render the entire string every
    -- frame, but i don't know any way to reduce the work done here using the
    -- primitives love offers.  probably not that big a deal anyway
    -- TODO ah, shouldn't rerender this if it didn't change though
    local joinedtext = ""
    for line = 1, self.curline do
         if line == self.curline then
            joinedtext = joinedtext .. string.sub(self.phrase_lines[line], 1, self.curchar)
        else
            joinedtext = joinedtext .. self.phrase_lines[line] .. "\n"
        end
    end
    -- Draw the text, twice: once for a drop shadow, then the text itself
    local text = love.graphics.newText(m5x7, joinedtext)
    love.graphics.setColor(0, 0, 0, 128)
    love.graphics.draw(text, HORIZ_TEXT_MARGIN - 2, boxtop + 32 + 2)
    love.graphics.setColor(255, 255, 255)
    love.graphics.draw(text, HORIZ_TEXT_MARGIN, boxtop + 32)

    -- Draw the speakers
    -- TODO wish these had anchors too so i could draw them from the bottom left and right
    self.speakers.isaac.sprite:draw_at(Vector(boxwidth - 32 - 64 * SPEAKER_SCALE, boxtop - 96 * SPEAKER_SCALE))
    self.speakers.lexy.sprite:draw_at(Vector(32, boxtop - 96 * SPEAKER_SCALE))
end

return DialogueScene
