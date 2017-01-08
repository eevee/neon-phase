local utf8 = require 'utf8'

local Class = require 'vendor.hump.class'
local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local ResourceManager = require 'klinklang.resources'
local WorldScene = require 'klinklang.scenes.world'
local Sprite = require 'klinklang.sprite'
local TiledMap = require 'klinklang.tiledmap'

local DialogueScene = require 'klinklang.scenes.dialogue'


game = {
    debug = false,
    sprites = {},
}

local TILE_SIZE = 32


--------------------------------------------------------------------------------

function love.load(args)
    for i, arg in ipairs(args) do
        if arg == '--xyzzy' then
            print('Nothing happens.')
            game.debug = true
        end
    end

    love.graphics.setDefaultFilter('nearest', 'nearest', 1)

    -- Load all the graphics upfront
    -- TODO i wouldn't mind having this defined in some json
    local character_sheet = love.graphics.newImage('assets/images/isaac.png')
    -- TODO istm i'll end up repeating this bit a lot
    game.sprites.isaac = Sprite(character_sheet, TILE_SIZE, TILE_SIZE * 2, 0, 0)
    game.sprites.isaac:add_pose('stand', {1, 1}, 0.05, 'pauseAtEnd')
    game.sprites.isaac:add_pose('walk', {'2-9', 1}, 0.1)
    game.sprites.isaac:add_pose('fall', {'10-11', 1}, 0.1)
    game.sprites.isaac:add_pose('jump', {'12-13', 1}, 0.05, 'pauseAtEnd')
    game.sprites.isaac:add_pose('die', {'14-18', 1}, 0.1, 'pauseAtEnd')

    -- TODO list resources to load declaratively and actually populate them in this function?
    p8_spritesheet = love.graphics.newImage('assets/images/spritesheet.png')
    game.sprites.staff = Sprite(p8_spritesheet, TILE_SIZE, TILE_SIZE, 0, 0)
    game.sprites.staff:add_pose('default', {1, 4}, 1, 'pauseAtEnd')
    game.sprites.spikes_up = Sprite(p8_spritesheet, TILE_SIZE, TILE_SIZE, 0, 0)
    game.sprites.spikes_up:add_pose('default', {9, 1}, 1, 'pauseAtEnd')
    game.sprites.wooden_switch = Sprite(p8_spritesheet, TILE_SIZE, TILE_SIZE, 0, 0)
    game.sprites.wooden_switch:add_pose('default', {9, 4}, 1, 'pauseAtEnd')
    game.sprites.wooden_switch:add_pose('switched', {10, 4}, 1, 'pauseAtEnd')
    game.sprites.magical_bridge = Sprite(p8_spritesheet, TILE_SIZE, TILE_SIZE, 0, 0)
    game.sprites.magical_bridge:add_pose('default', {11, 3}, 1, 'pauseAtEnd')
    game.sprites.savepoint = Sprite(p8_spritesheet, TILE_SIZE, TILE_SIZE, 0, 0)
    game.sprites.savepoint:add_pose(
        'default', {'3-15', 2},
        {
            -- Initial appearance: 6 frames
            0.05, 0.05, 0.05, 0.05, 0.05, 0.05,
            -- Default sprite
            2.5,
            -- Shimmer: 6 frames
            0.1, 0.1, 0.1, 0.1, 0.1, 0.1,
        },
        function(anim) anim:gotoFrame(7) end
    )
    game.sprites.laser_eye = Sprite(p8_spritesheet, TILE_SIZE, TILE_SIZE, 0, 0)
    game.sprites.laser_eye:add_pose('default', {11, 4}, 1, 'pauseAtEnd')
    game.sprites.laser_eye:add_pose('awake', {12, 4}, 1, 'pauseAtEnd')
    game.sprites.laser_vert = Sprite(p8_spritesheet, TILE_SIZE, TILE_SIZE, 0, 0)
    game.sprites.laser_vert:add_pose('default', {11, 5}, 1, 'pauseAtEnd')
    game.sprites.laser_vert:add_pose('end', {12, 5}, 1, 'pauseAtEnd')
    game.sprites.stone_door_shutter = Sprite(p8_spritesheet, TILE_SIZE, TILE_SIZE, 0, 0)
    game.sprites.stone_door_shutter:add_pose('default', {12, 3}, 1, 'pauseAtEnd')
    game.sprites.stone_door_shutter:add_pose('active', {12, 3, 15, 3}, 0.1)
    game.sprites.stone_door = Sprite(p8_spritesheet, TILE_SIZE, TILE_SIZE, 0, 0)
    game.sprites.stone_door:add_pose('default', {7, 3}, 1, 'pauseAtEnd')
    game.sprites.stone_door:add_pose('end', {8, 3}, 1, 'pauseAtEnd')
    game.sprites.wooden_wheel = Sprite(p8_spritesheet, TILE_SIZE, TILE_SIZE, 0, 0)
    game.sprites.wooden_wheel:add_pose('default', {15, 4}, 1, 'pauseAtEnd')
    game.sprites.wooden_wheel:add_pose('turning', {'15-16', 4}, 0.1)
    game.sprites.tome_of_levitation = Sprite(p8_spritesheet, TILE_SIZE, TILE_SIZE, 0, 0)
    game.sprites.tome_of_levitation:add_pose('default', {3, 4}, 1, 'pauseAtEnd')

    dialogue_spritesheet = love.graphics.newImage('assets/images/dialogue.png')
    game.sprites.isaac_dialogue = Sprite(dialogue_spritesheet, 64, 96, 0, 0)
    game.sprites.isaac_dialogue:add_pose('default', {2, 1}, 1, 'pauseAtEnd')
    game.sprites.isaac_dialogue:add_pose('default/talk', {"2-3", 1}, 0.25)
    game.sprites.lexy_dialogue = Sprite(dialogue_spritesheet, 64, 96, 0, 0)
    game.sprites.lexy_dialogue:add_pose('default', {1, 1}, 1, 'pauseAtEnd')
    game.sprites.lexy_dialogue:add_pose('default/talk', {1, 1, 4, 1}, 0.25)
    game.sprites.lexy_dialogue:add_pose('yeahsure', {6, 1}, 1, 'pauseAtEnd')
    game.sprites.lexy_dialogue:add_pose('yeahsure/talk', {6, 1, 5, 1}, 0.25)

    dialogueboximg = love.graphics.newImage('assets/images/isaac-dialogue.png')
    dialogueboximg2 = love.graphics.newImage('assets/images/lexy-dialogue.png')
    local fontscale = 2
    m5x7 = love.graphics.newFont('assets/fonts/m5x7.ttf', 16 * fontscale)
    --m5x7:setLineHeight(0.75)  -- TODO figure this out for sure
    love.graphics.setFont(m5x7)

    local resource_manager = ResourceManager()
    resource_manager:register_default_loaders()
    resource_manager.locked = false  -- TODO make an api for this lol
    game.resource_manager = resource_manager
    resource_manager:load('assets/sounds/jump.ogg')
    resource_manager:load('assets/music/square-one.ogg')

    game.maps = {
        'pico8-01.tmx.json',
        'pico8-02.tmx.json',
        'pico8-03.tmx.json',
        'pico8-04.tmx.json',
        'pico8-05.tmx.json',
        'pico8-06.tmx.json',
        'pico8-07.tmx.json',
        'pico8-08.tmx.json',
        'pico8-09.tmx.json',
        'pico8-10.tmx.json',
        'pico8-11.tmx.json',
    }
    -- TODO should maps instead hardcode their next maps?  or should they just
    -- have a generic "exit" a la doom?
    game.map_index = 7
    map = TiledMap("data/maps/" .. game.maps[game.map_index], resource_manager)
    --map = TiledMap("data/maps/slopetest.tmx.json", resource_manager)
    worldscene = WorldScene()
    worldscene:load_map(map)

    Gamestate.registerEvents()
    Gamestate.switch(worldscene)
    --local tmpscene = DialogueScene(worldscene)
    --Gamestate.switch(tmpscene)
end

function love.draw()
    love.graphics.print(tostring(love.timer.getFPS( )), 10, 10)
end
