local flux = require 'vendor.flux'
local tick = require 'vendor.tick'
local Gamestate = require 'vendor.hump.gamestate'
local Vector = require 'vendor.hump.vector'

local actors_base = require 'klinklang.actors.base'
local Player = require 'klinklang.actors.player'
local BaseScene = require 'klinklang.scenes.base'
local PauseScene = require 'klinklang.scenes.pause'
local whammo = require 'klinklang.whammo'

local tiledmap = require 'klinklang.tiledmap'
local Glitch = require 'neonphase.glitch'

local CAMERA_MARGIN = 0.4

-- FIXME game-specific...  but maybe it doesn't need to be
local TriggerZone = require 'neonphase.actors.trigger'

local WorldScene = BaseScene:extend{
    __tostring = function(self) return "worldscene" end,

    fluct = nil,
    tick = nil,

    using_gamepad = false,
    was_left_down = false,
    was_right_down = false,
}

--------------------------------------------------------------------------------
-- hump.gamestate hooks

function WorldScene:init(...)
    BaseScene.init(self, ...)

    self.camera = Vector()
    self:_refresh_canvas()

    -- FIXME well, i guess, don't actually fix me, but, this is used to stash
    -- entire maps atm too
    self.stashed_submaps = {}

    self.glitch = Glitch()
end

function WorldScene:_refresh_canvas()
    local w, h = game:getDimensions()
    self.canvas = love.graphics.newCanvas(w, h)
end

function WorldScene:update(dt)
    -- Handle movement input.
    -- Input comes in two flavors: "instant" actions that happen once when a
    -- button is pressed, and "continuous" actions that happen as long as a
    -- button is held down.
    -- "Instant" actions need to be handled in keypressed, but "continuous"
    -- actions need to be handled with an explicit per-frame check.  The
    -- difference is that a press might happen in another scene (e.g. when the
    -- game is paused), which for instant actions should be ignored, but for
    -- continuous actions should start happening as soon as we regain control —
    -- even though we never know a physical press happened.
    -- Walking has the additional wrinkle that there are two distinct inputs.
    -- If both are held down, then we want to obey whichever was held more
    -- recently, which means we also need to track whether they were held down
    -- last frame.
    local is_left_down = love.keyboard.isScancodeDown('left')
    local is_right_down = love.keyboard.isScancodeDown('right')
    -- FIXME should probably have some notion of a "current gamepad"?  should
    -- only one control scheme work at a time?  how is this usually handled omg
    for i, joystick in ipairs(love.joystick.getJoysticks()) do
        if joystick:isGamepad() then
            if joystick:isGamepadDown('dpleft') then
                is_left_down = true
            end
            if joystick:isGamepadDown('dpright') then
                is_right_down = true
            end
            local axis = joystick:getGamepadAxis('leftx')
            if axis < -0.25 then
                is_left_down = true
            elseif axis > 0.25 then
                is_right_down = true
            end
        end
    end
    if is_left_down and is_right_down then
        if self.was_left_down and self.was_right_down then
            -- Continuing to hold both keys; do nothing
        elseif self.was_left_down then
            -- Was holding left, also pressed right, so move right
            self.player:decide_walk(1)
        elseif self.was_right_down then
            -- Was holding right, also pressed left, so move left
            self.player:decide_walk(-1)
        else
            -- Miraculously went from holding neither to holding both, so let's
            -- not move at all
            self.player:decide_walk(0)
        end
    elseif is_left_down then
        self.player:decide_walk(-1)
    elseif is_right_down then
        self.player:decide_walk(1)
    else
        self.player:decide_walk(0)
    end
    self.was_left_down = is_left_down
    self.was_right_down = is_right_down
    -- Jumping is slightly more subtle.  The initial jump is an instant action,
    -- but /continuing/ to jump is a continuous action.  So we handle the
    -- initial jump in keypressed, but abandon a jump here as soon as the key
    -- is no longer held.
    local still_jumping = false
    if love.keyboard.isScancodeDown('space') then
        still_jumping = true
    end
    for i, joystick in ipairs(love.joystick.getJoysticks()) do
        if joystick:isGamepad() then
            if joystick:isGamepadDown('a') then
                still_jumping = true
                break
            end
        end
    end
    if not still_jumping then
        self.player:decide_abandon_jump()
    end

    if self.player.ptrs.chip then
        local chip_fire = love.keyboard.isScancodeDown('d')
        for i, joystick in ipairs(love.joystick.getJoysticks()) do
            if joystick:isGamepad() then
                if joystick:isGamepadDown('b') then
                    chip_fire = true
                end
            end
        end
        self.player.ptrs.chip:decide_fire(chip_fire)
    end

    if love.keyboard.isDown(',') then
        local Gamestate = require 'vendor.hump.gamestate'
        Gamestate.switch(self)
    end
    if self.inventory_switch then
        self.inventory_switch.progress = self.inventory_switch.progress + dt * 3
        if self.inventory_switch.progress >= 2 then
            self.inventory_switch = nil
        end
    end

    self.fluct:update(dt)
    self.tick:update(dt)

    -- Update the music to match the player's current position
    local x, y = self.player.pos:unpack()
    local new_music = false
    for shape, music in pairs(self.map.music_zones) do
        -- FIXME don't have a real api for this yet oops
        local x0, y0, x1, y1 = shape:bbox()
        if x0 <= x and x <= x1 and y0 <= y and y <= y1 then
            new_music = music
            break
        end
    end
    if self.music == new_music then
        -- Do nothing
    elseif new_music == false then
        -- Didn't find a zone at all; keep current music
    elseif self.music == nil then
        new_music:setLooping(true)
        new_music:play()
        self.music = new_music
    elseif new_music == nil then
        self.music:stop()
        self.music = nil
    else
        -- FIXME crossfade?
        new_music:setLooping(true)
        new_music:play()
        new_music:seek(self.music:tell())
        self.music:stop()
        self.music = new_music
    end

    for _, actor in ipairs(self.actors) do
        actor:update(dt)
    end

    self:update_camera()
end

function WorldScene:update_camera()
    -- Update camera position
    -- TODO i miss having a box type
    -- FIXME would like some more interesting features here like smoothly
    -- catching up with the player, platform snapping?
    if self.player then
        local focus = self.player.pos
        local w, h = game:getDimensions()
        local mapx, mapy = 0, 0

        local marginx = CAMERA_MARGIN * w
        local x0 = marginx
        local x1 = w - marginx
        local minx = 0
        local maxx = self.map.width - w
        local newx = self.camera.x
        if focus.x - newx < x0 then
            newx = focus.x - x0
        elseif focus.x - newx > x1 then
            newx = focus.x - x1
        end
        newx = math.max(minx, math.min(maxx, newx))
        self.camera.x = math.floor(newx)

        local marginy = CAMERA_MARGIN * h
        local y0 = marginy
        local y1 = h - marginy
        local miny = 0
        local maxy = self.map.height - h
        local newy = self.camera.y
        if focus.y - newy < y0 then
            newy = focus.y - y0
        elseif focus.y - newy > y1 then
            newy = focus.y - y1
        end
        newy = math.max(miny, math.min(maxy, newy))
        self.camera.y = math.floor(newy)
    end
end

function WorldScene:draw()
    local w, h = game:getDimensions()
    love.graphics.setCanvas(self.canvas)

    love.graphics.push('all')
    love.graphics.translate(-self.camera.x, -self.camera.y)

    -- TODO later this can expand into drawing all the layers automatically
    -- (the main problem is figuring out where exactly the actor layer lives)
    self.map:draw_parallax_background(self.camera, w, h)

    -- TODO once the camera is set up, consider rigging the map to somehow
    -- auto-expand to fill the screen?
    -- FIXME don't really like hardcoding layer names here; they /have/ an
    -- order, the main problem is just that there's no way to specify where the
    -- actors should be drawn
    self.map:draw('background', self.camera, w, h)
    self.map:draw('main terrain', self.camera, w, h)

    local actors_faucet
    if self.pushed_actors then
        self:_draw_actors(self.pushed_actors)
    else
        self:_draw_actors(self.actors)
    end

    self.map:draw('objects', self.camera, w, h)
    self.map:draw('foreground', self.camera, w, h)
    self.map:draw('wiring', self.camera, w, h)

    if self.pushed_actors then
        love.graphics.setColor(0, 0, 0, 192)
        love.graphics.rectangle('fill', self.camera.x, self.camera.y, w, h)
        love.graphics.setColor(255, 255, 255)
        -- FIXME stop hardcoding fuckin layer names
        self.map:draw(self.submap, self.camera, w, h)
        for _, actor in ipairs(self.actors) do
            self:_draw_actors(self.actors)
        end
    end

    -- Draw a button hint for the player when at something usable
    if self.player.touching_mechanism then
        local bubble = game.sprites['thought bubble']:instantiate()
        local letter
        if self.using_gamepad then
            letter = 'X'
            bubble:set_pose('button')
        else
            letter = 'E'
            bubble:set_pose('key')
        end
        -- FIXME ugggh this is annoying, and i think i do it somewhere else too
        bubble:update(0)
        local anchor = self.player.pos + Vector(-4, -32)
        bubble:draw_at(anchor)
        love.graphics.push('all')
        love.graphics.setColor(0, 0, 0)
        love.graphics.setFont(m5x7small)
        love.graphics.print(letter, math.floor(anchor.x - 8), math.floor(anchor.y - 28))
        love.graphics.pop()
    end


    if game.debug then
        --[[
        for shape in pairs(self.collider.shapes) do
            shape:draw('line')
        end
        ]]
        for _, actor in ipairs(self.actors) do
            if actor.shape then
                love.graphics.setColor(255, 255, 0, 192)
                actor.shape:draw('line')
            end
            love.graphics.setColor(255, 0, 0)
            love.graphics.circle('fill', actor.pos.x, actor.pos.y, 2)
            love.graphics.setColor(255, 255, 255)
            love.graphics.circle('line', actor.pos.x, actor.pos.y, 2)
        end

        if debug_hits then
            for hit, touchtype in pairs(debug_hits) do
                if touchtype > 0 then
                    -- Collision: red
                    love.graphics.setColor(255, 0, 0, 128)
                elseif touchtype < 0 then
                    -- Overlap: blue
                    love.graphics.setColor(0, 64, 255, 128)
                else
                    -- Touch: green
                    love.graphics.setColor(0, 192, 0, 128)
                end
                hit:draw('fill')
                --love.graphics.setColor(255, 255, 0)
                --local x, y = hit:bbox()
                --love.graphics.print(("%0.2f"):format(d), x, y)
            end
        end
    end

    love.graphics.pop()

    self.glitch:apply()
    love.graphics.setCanvas()
    love.graphics.draw(self.canvas, 0, 0, 0, game.scale, game.scale)
    love.graphics.setShader()

    if game.debug then
        self:_draw_blockmap()
    end
end

function WorldScene:_draw_actors(actors)
    local sorted_actors = {}
    for k, v in ipairs(actors) do
        sorted_actors[k] = v
    end

    table.sort(sorted_actors, function(actor1, actor2)
        return (actor1.z or 0) < (actor2.z or 0)
    end)

    for _, actor in ipairs(sorted_actors) do
        actor:draw()
    end
end

function WorldScene:_draw_blockmap()
    love.graphics.push('all')
    love.graphics.setColor(255, 255, 255, 64)
    love.graphics.scale(game.scale, game.scale)

    local blockmap = self.collider.blockmap
    local blocksize = blockmap.blocksize
    local x0 = -self.camera.x % blocksize
    local y0 = -self.camera.y % blocksize
    local w, h = game:getDimensions()
    for x = x0, w, blocksize do
        love.graphics.line(x, 0, x, h)
    end
    for y = y0, h, blocksize do
        love.graphics.line(0, y, w, y)
    end

    for x = x0, w, blocksize do
        for y = y0, h, blocksize do
            local a, b = blockmap:to_block_units(self.camera.x + x, self.camera.y + y)
            love.graphics.print((" %d, %d"):format(a, b), x, y)
        end
    end

    love.graphics.pop()
end

function WorldScene:resize(w, h)
    self:_refresh_canvas()
end

-- FIXME this is really /all/ game-specific
function WorldScene:keypressed(key, scancode, isrepeat)
    self.using_gamepad = false
    if isrepeat then
        return
    end

    if scancode == 'space' then
        self.player:decide_jump()
    elseif scancode == 'e' then
        -- Use inventory item, or nearby thing
        -- FIXME this should be separate keys maybe?
        if self.player.touching_mechanism then
            self.player.touching_mechanism:on_use(self.player)
        elseif self.player.inventory_cursor > 0 then
            self.player.inventory[self.player.inventory_cursor]:on_inventory_use(self.player)
        end
    elseif scancode == 's' and not isrepeat then
        -- FIXME if initial attempt doesn't work, every subsequent frame should try again
        self.player:grab_chip()
    elseif scancode == 'pause' then
        -- FIXME ignore if modifiers?
        Gamestate.push(PauseScene())
    end
end

function WorldScene:keyreleased(key, scancode)
    if scancode == 's' then
        self.player:release_chip()
    end
end

function WorldScene:gamepadpressed(joystick, button)
    self.using_gamepad = true
    if button == 'a' then
        self.player:decide_jump()
    elseif button == 'x' then
        -- Use inventory item, or nearby thing
        if self.player.touching_mechanism then
            self.player.touching_mechanism:on_use(self.player)
        end
    elseif button == 'leftshoulder' then
        -- FIXME should work with left trigger too, but that's analog so has no
        -- event.  also i'm gradually going off the press events anyway
        self.player:grab_chip()
    end
end

function WorldScene:gamepadreleased(joystick, button)
    if button == 'leftshoulder' then
        self.player:release_chip()
    end
end

function WorldScene:mousepressed(x, y, button, istouch)
    if game.debug and button == 3 then
        self.player.pos.x = x / game.scale + self.camera.x
        self.player.pos.y = y / game.scale + self.camera.y
    end
end

--------------------------------------------------------------------------------
-- API

function WorldScene:load_map(map)
    self.map = map
    self.music = nil
    self.fluct = flux.group()
    self.tick = tick.group()

    if self.stashed_submaps[map] then
        self.actors = self.stashed_submaps[map].actors
        self.collider = self.stashed_submaps[map].collider
        self.camera = self.player.pos:clone()
        self:update_camera()
        self.glitch:play_glitch_effect()
        -- XXX this is really half-assed, relies on the caller to add the player back to the map too
        return
    end

    self.actors = {}
    self.collider = whammo.Collider(4 * map.tilewidth)
    self.stashed_submaps[map] = {
        actors = self.actors,
        collider = self.collider,
    }

    -- TODO this seems clearly wrong, especially since i don't clear the
    -- collider, but it happens to work (i think)
    map:add_to_collider(self.collider)

    local player_start = self.map.player_start
    -- FIXME fix all the maps and then make this fatal
    if not player_start then
        print("WARNING: no player start!!")
        player_start = Vector(1 * map.tilewidth, 5 * map.tileheight)
    end
    if not self.player then
        self.player = Player(player_start:clone())
    else
        self.player:move_to(player_start:clone())
    end

    -- TODO this seems more a candidate for an 'enter' or map-switch event
    self:_create_actors()

    -- FIXME this is invasive
    -- FIXME should probably just pass the slightly-munged object right to the constructor, instead of special casing these
    -- FIXME could combine this with player start detection maybe
    for _, layer in pairs(map.layers) do
        if layer.type == 'objectgroup' and layer.submap == nil then
            for _, object in ipairs(layer.objects) do
                if object.type == 'trigger' then
                    self:add_actor(TriggerZone(
                        Vector(object.x, object.y),
                        Vector(object.width, object.height),
                        object.properties))
                end
            end
        end
    end

    -- FIXME putting the player last is really just a z hack to make the player
    -- draw in front of everything else
    self:add_actor(self.player)

    -- Rez the player if necessary.  This MUST happen after moving the player
    -- (and SHOULD happen after populating the world, anyway) because it does a
    -- zero-duration update, and if the player is still touching whatever
    -- killed them, they'll instantly die again.
    if self.player.is_dead then
        -- TODO should this be a more general 'reset'?
        self.player:resurrect()
    end

    self.camera = self.player.pos:clone()
    self:update_camera()
    self.glitch:play_glitch_effect()
end

function WorldScene:reload_map()
    self:load_map(self.map)
end

function WorldScene:_create_actors(submap)
    for _, template in ipairs(self.map.actor_templates) do
        if template.submap == submap then
            local class = actors_base.Actor:get_named_type(template.name)
            local position = template.position:clone()
            local actor = class(position, template.properties)
            -- FIXME this feels...  hokey...
            if actor.sprite.anchor then
                actor:move_to(position + actor.sprite.anchor)
            end
            self:add_actor(actor)
        end
    end
end

function WorldScene:enter_submap(name)
    self.glitch:play_transition_effect()

    -- FIXME this is extremely half-baked
    self.submap = name
    self:remove_actor(self.player)
    self.pushed_actors = self.actors
    self.pushed_collider = self.collider

    -- FIXME get rid of pushed in favor of this?  but still need to establish the stack
    if self.stashed_submaps[name] then
        self.actors = self.stashed_submaps[name].actors
        self.collider = self.stashed_submaps[name].collider
        self:add_actor(self.player)
        return
    end

    self.actors = {}
    self.collider = whammo.Collider(4 * self.map.tilewidth)
    self.stashed_submaps[name] = {
        actors = self.actors,
        collider = self.collider,
    }
    self.map:add_to_collider(self.collider, self.submap)
    self:add_actor(self.player)

    self:_create_actors(self.submap)

    -- FIXME this is also invasive
    for _, layer in pairs(self.map.layers) do
        if layer.type == 'objectgroup' and layer.submap == self.submap then
            for _, object in ipairs(layer.objects) do
                if object.type == 'trigger' then
                    self:add_actor(TriggerZone(
                        Vector(object.x, object.y),
                        Vector(object.width, object.height),
                        object.properties))
                end
            end
        end
    end
end

function WorldScene:leave_submap(name)
    self.glitch:play_transition_effect()

    -- FIXME this is extremely half-baked
    self.submap = nil
    self:remove_actor(self.player)
    self.actors = self.pushed_actors
    self.collider = self.pushed_collider
    self.pushed_actors = nil
    self.pushed_collider = nil
    self:add_actor(self.player)
end

function WorldScene:add_actor(actor)
    table.insert(self.actors, actor)

    if actor.shape then
        -- TODO what happens if the shape changes?
        self.collider:add(actor.shape, actor)
    end

    actor:on_enter()
end

function WorldScene:remove_actor(actor)
    -- TODO what if the actor is the player...?  should we unset self.player?
    actor:on_leave()

    -- TODO maybe an index would be useful
    for i, an_actor in ipairs(self.actors) do
        if actor == an_actor then
            local last = #self.actors
            self.actors[i] = self.actors[last]
            self.actors[last] = nil
            break
        end
    end

    if actor.shape then
        self.collider:remove(actor.shape)
    end
end


return WorldScene
