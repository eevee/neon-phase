local utf8 = require 'utf8'

local Gamestate = require 'vendor.hump.gamestate'
local tick = require 'vendor.tick'

local ResourceManager = require 'klinklang.resources'
local DialogueScene = require 'klinklang.scenes.dialogue'
local WorldScene = require 'klinklang.scenes.world'
local SpriteSet = require 'klinklang.sprite'
local tiledmap = require 'klinklang.tiledmap'


game = {
    TILE_SIZE = 16,

    progress = {
        flags = {},
    },

    debug = false,
    resource_manager = nil,
    -- FIXME this seems ugly, but the alternative is to have sprite.lua implicitly depend here
    sprites = SpriteSet._all_sprites,

    scale = 1,

    _determine_scale = function(self)
        -- Default resolution is 640 × 360, which is half of 720p and a third
        -- of 1080p and equal to 40 × 22.5 tiles.  With some padding, I get
        -- these as the max viewport size.
        local w, h = love.graphics.getDimensions()
        local MAX_WIDTH = 50 * 16
        local MAX_HEIGHT = 30 * 16
        self.scale = math.ceil(math.max(w / MAX_WIDTH, h / MAX_HEIGHT))
    end,

    getDimensions = function(self)
        return love.graphics.getWidth() / self.scale, love.graphics.getHeight() / self.scale
    end,
}

local TILE_SIZE = 16


--------------------------------------------------------------------------------

function love.load(args)
    for i, arg in ipairs(args) do
        if arg == '--xyzzy' then
            print('Nothing happens.')
            game.debug = true
        end
    end

    love.graphics.setDefaultFilter('nearest', 'nearest', 1)

    -- Eagerly load all actor modules, so we can access them by name
    for _, package in ipairs{'klinklang', 'neonphase'} do
        local dir = package .. '/actors'
        for _, filename in ipairs(love.filesystem.getDirectoryItems(dir)) do
            -- FIXME this should recurse, but i can't be assed right now
            if filename:match("%.lua$") and love.filesystem.isFile(dir .. '/' .. filename) then
                module = package .. '.actors.' .. filename:sub(1, #filename - 4)
                require(module)
            end
        end
    end

    local resource_manager = ResourceManager()
    resource_manager:register_default_loaders()
    resource_manager.locked = false  -- TODO make an api for this lol
    game.resource_manager = resource_manager

    -- Eagerly load all sound effects, which we will surely be needing
    local sounddir = 'assets/sounds'
    for _, filename in ipairs(love.filesystem.getDirectoryItems(sounddir)) do
        -- FIXME recurse?
        local path = sounddir .. '/' .. filename
        if love.filesystem.isFile(path) then
            resource_manager:load(path)
        end
    end

    -- FIXME parallax bgs -- should live in data somewhere
    resource_manager:load('assets/images/dustybg1.png')
    resource_manager:load('assets/images/dustybg2.png')
    resource_manager:load('assets/images/dustybg3.png')

    DialogueScene.default_background = game.resource_manager:load('assets/images/dialoguebox.png')

    -- Load all the graphics upfront
    -- FIXME should...  iterate through tilesets i guess?
    for _, tspath in ipairs{
        'data/tilesets/kidneon.tsx.json',
        'data/tilesets/chip.tsx.json',
        'data/tilesets/energyball.tsx.json',
        'data/tilesets/portraits.tsx.json',
        'data/tilesets/decor.tsx.json',
        'data/tilesets/voidkn.tsx.json',
    } do
        local tileset = tiledmap.TiledTileset(tspath, nil, resource_manager)
        resource_manager:add(tspath, tileset)
    end

    -- FIXME probably want a way to specify fonts with named roles
    local fontscale = 2
    m5x7 = love.graphics.newFont('assets/fonts/m5x7.ttf', 16 * fontscale)
    -- FIXME figure out the right value here
    -- FIXME note that unlike css, this doesn't vertically center; it trims
    -- space from the /bottom/, whereas m5x7 has extra space at the /top/
    --m5x7:setLineHeight(0.75)
    love.graphics.setFont(m5x7)
    m5x7small = love.graphics.newFont('assets/fonts/m5x7.ttf', 16 * 1)

    worldscene = WorldScene()

    Gamestate.registerEvents()
    local TitleScene = require('neonphase.scenes.title')
    Gamestate.switch(TitleScene(worldscene, "data/maps/map.tmx.json"))
    --local CreditsScene = require('neonphase.scenes.credits')
    --Gamestate.switch(CreditsScene())
end

function love.update(dt)
    tick.update(dt)
end

function love.draw()
end

local _previous_mode

function love.resize(w, h)
    game:_determine_scale()
end

function love.keypressed(key, scancode, isrepeat)
    if key == 'return' and not isrepeat and love.keyboard.isDown('lalt', 'ralt') then
        if love.window.getFullscreen() then
            love.window.setMode(unpack(_previous_mode))
            -- This isn't called for resizes caused by code, but worldscene
            -- etc. sort of rely on knowing this
            love.resize(love.graphics.getDimensions())
        else
            _previous_mode = {love.window.getMode()}
            love.window.setFullscreen(true)
        end
    end
end
