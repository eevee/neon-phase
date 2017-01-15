local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local BaseScene = require 'klinklang.scenes.base'

local SPEAKER_SCALE = 4
local SCROLL_RATE = 64  -- characters per second

-- Magic rendering numbers
local TEXT_MARGIN_X = 24
local TEXT_MARGIN_Y = 16

local DialogueScene = BaseScene:extend{
    __tostring = function(self) return "dialoguescene" end,
}

-- TODO as with DeadScene, it would be nice if i could formally eat keyboard input
-- FIXME document the shape of speakers/script, once we know what it is
function DialogueScene:init(speakers, script)
    BaseScene.init(self)

    self.wrapped = nil

    -- FIXME unhardcode some more of this, adjust it on resize
    local w, h = game:getDimensions()
    self.speaker_height = 80
    local boxheight = 120
    local winheight = h
    self.speaker_scale = math.floor((winheight - boxheight) / self.speaker_height)

    -- TODO a good start, but
    self.speakers = speakers
    for name, speaker in pairs(speakers) do
        -- FIXME maybe speakers should only provide a spriteset so i'm not
        -- changing out from under them
        if speaker.sprite then
            speaker.sprite:set_scale(self.speaker_scale)
            if speaker.position == 'right' then
                speaker.sprite:set_facing_right(false)
            end
        end
    end

    self.script = script
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
    self.wraplimit = w - TEXT_MARGIN_X * 2

    self.script_index = 0

    self:_advance_script()
end

function DialogueScene:enter(previous_scene)
    self.wrapped = previous_scene
end

function DialogueScene:update(dt)
    for _, speaker in pairs(self.speakers) do
        if speaker.sprite then
            speaker.sprite:update(dt)
        end
    end
    -- FIXME no way to specify facing direction atm

    if self.state == 'speaking' then
        self.phrase_timer = self.phrase_timer + dt * SCROLL_RATE
        -- Show as many new characters as necessary, based on time elapsed
        while self.phrase_timer >= 1 do
            -- Advance cursor, continuing across lines if necessary
            self.curchar = self.curchar + 1
            if self.curchar > string.len(self.phrase_lines[self.curline]) then
                if self.curline == #self.phrase_lines then
                    self.state = 'waiting'
                    if self.phrase_speaker.sprite then
                        self.phrase_speaker.sprite:set_pose(self.phrase_speaker.pose)
                    end
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

function DialogueScene:_advance_script()
    while true do
        if self.script_index >= #self.script then
            -- TODO actually not sure what should happen here
            self.state = 'done'
            Gamestate.pop()
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
            -- FIXME need a less hardcoded way to specify talking sprites; probably just only animate them while talking
            if self.phrase_speaker.sprite then
                self.phrase_speaker.sprite:set_pose(self.phrase_speaker.pose)
            end
            self.phrase_timer = 0
            self.curline = 1
            self.curchar = 0
            break
        else
            -- Textless steps are commands
            -- TODO this is super hokey at the moment dang
            local speaker = self.speakers[step.speaker]
            speaker.pose = step.pose
            if speaker.sprite then
                speaker.sprite:set_pose(step.pose)
            end
        end
    end
end

function DialogueScene:draw()
    self.wrapped:draw()

    love.graphics.push('all')
    love.graphics.scale(game.scale, game.scale)
    love.graphics.setColor(0, 0, 0, 64)
    love.graphics.rectangle('fill', 0, 0, game:getDimensions())
    love.graphics.setColor(255, 255, 255)

    -- Draw the dialogue box, which is slightly complicated because it involves
    -- drawing the ends and then repeating the middle bit to fit the screen
    -- size
    local background = self.phrase_speaker.background
    -- TODO this feels rather hardcoded; surely the background should flex to fit the height rather than defining it.
    local boxheight = background:getHeight()
    boxheight = 120
    local w, h = game:getDimensions()
    local boxwidth = w
    local boxtop = h - boxheight

    local BOXSCALE = 1  -- FIXME this was 2 for isaac
    local boxrepeatleft, boxrepeatright = 192, 224
    local boxquadl = love.graphics.newQuad(0, 0, boxrepeatleft, background:getHeight(), background:getDimensions())
    love.graphics.draw(background, boxquadl, 0, boxtop, 0, BOXSCALE)
    local boxquadm = love.graphics.newQuad(boxrepeatleft, 0, boxrepeatright - boxrepeatleft, background:getHeight(), background:getDimensions())
    love.graphics.draw(background, boxquadm, boxrepeatleft * BOXSCALE, boxtop, 0, math.floor(w / (boxrepeatright - boxrepeatleft)) + 1, BOXSCALE)
    local boxquadr = love.graphics.newQuad(boxrepeatright, 0, background:getWidth() - boxrepeatright, background:getHeight(), background:getDimensions())
    love.graphics.draw(background, boxquadr, w - (background:getWidth() - boxrepeatright) * BOXSCALE, boxtop, 0, BOXSCALE)

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
    love.graphics.draw(text, TEXT_MARGIN_X - 2, boxtop + TEXT_MARGIN_Y + 2)
    if self.phrase_speaker.color then
        love.graphics.setColor(self.phrase_speaker.color)
    else
        love.graphics.setColor(255, 255, 255)
    end
    love.graphics.draw(text, TEXT_MARGIN_X, boxtop + TEXT_MARGIN_Y)

    -- Draw the speakers
    -- FIXME speakers really need to have, like, positions.  this is very hardcoded
    -- Left
    for _, speaker in pairs(self.speakers) do
        local sprite = speaker.sprite
        if sprite then
            local sw, sh = sprite.anim:getDimensions()
            local x
            if speaker.position == 'left' then
                x = math.floor(boxwidth / 4)
            elseif speaker.position == 'right' then
                x = math.floor(boxwidth * 3 / 4)
            end
            local pos = Vector(x - sw * self.speaker_scale / 2, boxtop - sh * self.speaker_scale)
            if speaker == self.phrase_speaker then
                love.graphics.setColor(255, 255, 255)
            else
                love.graphics.setColor(128, 128, 128)
            end
            sprite:draw_at(pos)
        end
    end

    love.graphics.pop()
end

function DialogueScene:keypressed(key, scancode, isrepeat)
    if key == 'space' then
        if self.state == 'waiting' then
            self:_advance_script()
        end
    end
end

function DialogueScene:resize(w, h)
    -- FIXME redo stuff
end

return DialogueScene
