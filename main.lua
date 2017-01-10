local utf8 = require 'utf8'

local Class = require 'vendor.hump.class'
local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local ResourceManager = require 'klinklang.resources'
local WorldScene = require 'klinklang.scenes.world'
local SpriteSet = require 'klinklang.sprite'
local tiledmap = require 'klinklang.tiledmap'

local DialogueScene = require 'klinklang.scenes.dialogue'


game = {
    TILE_SIZE = 16,

    debug = false,
    resource_manager = nil,
    -- FIXME this seems ugly, but the alternative is to have sprite.lua implicitly depend here
    sprites = SpriteSet._all_sprites,
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

    local resource_manager = ResourceManager()
    resource_manager:register_default_loaders()
    resource_manager.locked = false  -- TODO make an api for this lol
    game.resource_manager = resource_manager

    -- FIXME parallax bgs -- should live in data somewhere
    resource_manager:load('assets/images/dustybg1.png')
    resource_manager:load('assets/images/dustybg2.png')
    resource_manager:load('assets/images/dustybg3.png')

    -- Load all the graphics upfront
    -- FIXME should...  iterate through tilesets i guess?
    for _, tspath in ipairs{
        'data/tilesets/kidneon.tsx.json',
        'data/tilesets/chip.tsx.json',
        'data/tilesets/energyball.tsx.json',
    } do
        local tileset = tiledmap.TiledTileset(tspath, nil, resource_manager)
        resource_manager:add(tspath, tileset)
    end

    -- FIXME probably want a way to specify fonts with named roles
    local fontscale = 2
    m5x7 = love.graphics.newFont('assets/fonts/m5x7.ttf', 16 * fontscale)
    --m5x7:setLineHeight(0.75)  -- TODO figure this out for sure
    love.graphics.setFont(m5x7)

    game.maps = {
        'empty.tmx.json',
    }
    -- TODO should maps instead hardcode their next maps?  or should they just
    -- have a generic "exit" a la doom?
    game.map_index = 1
    map = tiledmap.TiledMap("data/maps/" .. game.maps[game.map_index], resource_manager)
    worldscene = WorldScene()
    worldscene:load_map(map)

    Gamestate.registerEvents()
    Gamestate.switch(worldscene)
end

function love.draw()
    love.graphics.print(tostring(love.timer.getFPS( )), 10, 10)
end

local _previous_mode

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
