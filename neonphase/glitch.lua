local tick = require 'vendor.tick'

local Object = require 'klinklang.object'


local Glitch = Object:extend()

-- Note that this uses the global tick timer, so it progresses even during
-- pauses or dialogue
function Glitch:init()
    local shader = love.graphics.newShader([[
        extern int y_bands;  // number of horizontal bands
        extern int y_chunk;  // how many bands constitute a chunk
        extern int y_min;
        extern int y_max;  // which bands in each chunk are distorted
        extern float y_offset;  // 0-1, how much to offset y by before sining
        extern float x_distortion;  // how much to offset x (in TEXTURES, not pixels!)

        vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
            int y = int(texture_coords.y * y_bands);
            while (y >= y_chunk) y -= y_chunk;
            if (y_min <= y && y <= y_max) {
                texture_coords.x += x_distortion * sin((texture_coords.y * y_bands + y_offset) * 6.28);
            }
            vec4 texcolor = Texel(texture, texture_coords);
            return texcolor * color;
        }
    ]])
    self.shader = shader
    self.shader:send('y_bands', 128)
    self.shader:send('y_chunk', 16)
    self.shader:send('y_offset', 0)
    self.active = false
end

-- occasional glitching, used for most of the world
function Glitch:play_glitch_effect()
    if self.event then
        self.event:stop()
    end

    self.shader:send('x_distortion', 1/128)
    local off = math.random(0, 15)
    self.shader:send('y_min', off)
    self.shader:send('y_offset', math.random())
    self.shader:send('y_max', off)
    self.active = false
    self.event = tick.delay(function()
        self.active = true
    end, math.random() * 4 + 8)
    self.event:after(function()
        self.active = false
        self:play_glitch_effect()
    end, 0.05)
end

-- more frequent glitching, used for void world
function Glitch:play_very_glitch_effect()
    if self.event then
        self.event:stop()
    end

    self.shader:send('x_distortion', math.random() * 1/16)
    local y_min = math.random(0, 11)
    self.shader:send('y_min', y_min)
    self.shader:send('y_max', y_min + math.random(1, 4))
    self.shader:send('y_offset', math.random())
    self.active = false
    self.event = tick.delay(function()
        self.active = true
    end, math.random() * 3 + 1)
    self.event:after(function()
        self.active = false
        self:play_very_glitch_effect()
    end, math.random() * 0.25 + 0.25)
end

-- brief full-screen glitch effect, used for going in and out of buildings
function Glitch:play_transition_effect()
    if self.event then
        self.event:stop()
    end

    self.active = false
    self.shader:send('x_distortion', 1/64)
    self.shader:send('y_min', 0)
    self.shader:send('y_max', 128)
    self.shader:send('y_offset', math.random())
    local delay = 0.5
    self.event = tick.delay(function()
        self.active = true
    end, 0.05)
    self.event:after(function()
        self:play_glitch_effect()
    end, 0.05)
end

-- heavy increasing full-screen glitch, used for leaving void world
function Glitch:play_extreme_glitch_transition()
    if self.event then
        self.event:stop()
    end

    self.active = false
    self.shader:send('x_distortion', 1/64)
    self.shader:send('y_min', 3)
    self.shader:send('y_max', 4)
    self.shader:send('y_offset', math.random())
    self.event = tick.delay(function() self.active = true end, 0.05)
    local chainend = self.event:after(function() self.active = false end, 0.05)
    :after(function()
        self.shader:send('x_distortion', 1/32)
        self.shader:send('y_min', 5)
        self.shader:send('y_max', 6)
        self.shader:send('y_offset', math.random())
        self.active = true
    end, 0.5)
    :after(function() self.active = false end, 0.1)
    :after(function()
        self.shader:send('x_distortion', 1/24)
        self.shader:send('y_min', 1)
        self.shader:send('y_max', 4)
        self.shader:send('y_offset', math.random())
        self.active = true
    end, 0.25)
    :after(function() self.active = false end, 0.15)
    :after(function()
        self.shader:send('x_distortion', 1/16)
        self.shader:send('y_min', 4)
        self.shader:send('y_max', 12)
        self.shader:send('y_offset', math.random())
        self.active = true
    end, 0.25)
    :after(function() self.active = false end, 0.2)
    :after(function()
        self.shader:send('x_distortion', 1/8)
        self.shader:send('y_min', 1)
        self.shader:send('y_max', 15)
        self.shader:send('y_offset', math.random())
        self.active = true
    end, 0.125)

    for i = 1, 20 do
        chainend = chainend:after(function()
            self.shader:send('x_distortion', math.random() * 0.25 + 0.25)
            self.shader:send('y_offset', math.random())
        end, 0.125)
    end
end

function Glitch:play_credits_glitch_effect()
    if self.event then
        self.event:stop()
    end

    self.shader:send('x_distortion', math.random() * 1/32)
    self.shader:send('y_offset', math.random())
    self.shader:send('y_min', 0)
    self.shader:send('y_max', 15)
    self.active = false
    self.event = tick.delay(function()
        self.active = true
    end, math.random() * 1 + 0.5)
    self.event:after(function()
        self.active = false
        self:play_credits_glitch_effect()
    end, math.random() * 0.05 + 0.05)
end


function Glitch:apply()
    if self.active then
        love.graphics.setShader(self.shader)
    end
end


return Glitch
