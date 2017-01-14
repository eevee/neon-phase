--[[
Read a map in Tiled's JSON format.
]]

local anim8 = require 'vendor.anim8'
local Vector = require 'vendor.hump.vector'
local json = require 'vendor.dkjson'

local Object = require 'klinklang.object'
local util = require 'klinklang.util'
local whammo_shapes = require 'klinklang.whammo.shapes'
local SpriteSet = require 'klinklang.sprite'


-- I hate silent errors
local function strict_json_decode(str)
    local obj, pos, err = json.decode(str)
    if err then
        error(err)
    else
        return obj
    end
end

-- TODO no idea how correct this is
-- n.b.: a is assumed to hold a /filename/, which is popped off first
local function relative_path(a, b)
    a = a:gsub("[^/]+$", "")
    while b:find("^%.%./") do
        b = b:gsub("^%.%./", "")
        a = a:gsub("[^/]+/?$", "")
    end
    if not a:find("/$") then
        a = a .. "/"
    end
    return a .. b
end


--------------------------------------------------------------------------------
-- TileProxy
--
-- Not a real tile object, but a little wrapper that can read its properties
-- from the Tiled JSON on the fly.

local TileProxy = Object:extend{}

function TileProxy:init()
end

--------------------------------------------------------------------------------
-- TiledTileset

local TiledTileset = Object:extend{}

function TiledTileset:init(path, data, resource_manager)
    self.path = path
    if not data then
        data = strict_json_decode(love.filesystem.read(path))
    end
    self.raw = data

    -- Copy some basics
    local iw, ih = data.imagewidth, data.imageheight
    local tw, th = data.tilewidth, data.tileheight
    self.imagewidth = iw
    self.imageheight = ih
    self.tilewidth = tw
    self.tileheight = th
    self.tilecount = data.tilecount
    self.columns = data.columns

    -- Fetch the image
    local imgpath = relative_path(path, data.image)
    self.image = resource_manager:load(imgpath)

    -- Double-check the image size matches
    local aiw, aih = self.image:getDimensions()
    if iw ~= aiw or ih ~= aih then
        error((
            "Tileset at %s claims to use a %d x %d image, but the actual " ..
            "image at %s is %d x %d -- if you resized the image, open the " ..
            "tileset in Tiled, and it should offer to fix this automatically"
            ):format(path, iw, ih, imgpath, aiw, aih))
    end

    -- Create a quad for each tile
    -- NOTE: This is NOT (quite) a Lua array; it's a map from Tiled's tile ids
    -- (which start at zero) to quads
    self.quads = {}
    for relid = 0, self.tilecount - 1 do
        -- TODO support spacing, margin
        local row, col = util.divmod(relid, self.columns)
        self.quads[relid] = love.graphics.newQuad(
            col * tw, row * th, tw, th, iw, ih)

        -- While we're in here: JSON necessitates that the keys for per-tile
        -- data are strings, but they're intended as numbers, so fix them up
        -- TODO surely this could be done as its own loop on the outside
        for _, key in ipairs{'tiles', 'tileproperties', 'tilepropertytypes'} do
            local tbl = data[key]
            if tbl then
                tbl[relid] = tbl["" .. relid]
                tbl["" .. relid] = nil
            end
        end
    end

    -- Read named sprites (and their animations, if appropriate)
    -- FIXME this probably shouldn't happen for a random-ass sprite we're
    -- reading from within a map, right?  maybe this should be a separate
    -- method that dumps the spritesets into a passed-in table (which would let
    -- me get rid of _all_sprites)
    -- FIXME this scheme is nice, except, there's no way to use the same frame
    -- for two poses?
    local spritesets = {}
    local grid = anim8.newGrid(tw, th, iw, ih, data.margin, data.margin, data.spacing)
    for id = 0, self.tilecount - 1 do
        -- Tile IDs are keyed as strings, because JSON
        --id = "" .. id
        -- FIXME uggh
        if data.tileproperties and data.tileproperties[id] and data.tileproperties[id]['sprite name'] then
            local full_sprite_name = data.tileproperties[id]['sprite name']
            local sprite_name, pose_name = full_sprite_name:match("^(.+)/(.+)$")
            local spriteset = spritesets[sprite_name]
            if not spriteset then
                spriteset = SpriteSet(sprite_name, self.image)
                spritesets[sprite_name] = spriteset
            end

            -- Collect the frames, as a list of quads
            local quads, durations, onloop, flipped
            if data.tiles and data.tiles[id] and data.tiles[id].animation then
                quads = {}
                durations = {}
                for _, animation_frame in ipairs(data.tiles[id].animation) do
                    table.insert(quads, self.quads[animation_frame.tileid])
                    table.insert(durations, animation_frame.duration / 1000)
                end
                if data.tileproperties[id]['animation stops'] then
                    onloop = 'pauseAtEnd'
                end
                if data.tileproperties[id]['animation flipped'] then
                    flipped = true
                end
            else
                quads = {self.quads[id]}
                durations = 1
                onloop = 'pauseAtEnd'
            end
            local shape, anchor = self:get_collision(id)
            spriteset:add(pose_name, anchor or Vector.zero, shape, quads, durations, onloop, flipped)
        end
    end
end

local function _tiled_shape_to_whammo_shape(object, anchor)
    local shape
    if object.polygon then
        local points = {}
        for i, pt in ipairs(object.polygon) do
            -- Sometimes Tiled repeats the first point as the last point, and
            -- sometimes it does not.  Duplicate points create zero normals,
            -- which are REALLY BAD (and turn the player's position into nan),
            -- so strip them out
            local j = i + 1
            if j > #object.polygon then
                j = 1
            end
            local nextpt = object.polygon[j]
            if pt.x ~= nextpt.x or pt.y ~= nextpt.y then
                table.insert(points, pt.x + object.x - anchor.x)
                table.insert(points, pt.y + object.y - anchor.y)
            end
        end
        shape = whammo_shapes.Polygon(unpack(points))
    else
        -- TODO do the others, once whammo supports them
        shape = whammo_shapes.Box(
            object.x - anchor.x, object.y - anchor.y, object.width, object.height)
    end

    -- FIXME this is pretty bad, right?  the collision system shouldn't
    -- need to know about this?  unless it should??  (a problem atm is
    -- that it gets ignored on a subshape
    if object.properties and object.properties['one-way platform'] then
        shape._xxx_is_one_way_platform = true
    end

    return shape
end

function TiledTileset:get_collision(tileid)
    if not self.raw.tiles then
        return
    end

    local tiledata = self.raw.tiles[tileid]
    if not tiledata or not tiledata.objectgroup then
        return
    end

    -- TODO extremely hokey -- assumes at least one, doesn't check for more
    -- than one, doesn't check shape, etc
    local objects = tiledata.objectgroup.objects
    if not objects or #objects == 0 then
        return
    end

    -- Find an anchor, if any
    local anchor = Vector()
    for _, obj in ipairs(objects) do
        if obj.type == "anchor" then
            anchor.x = obj.x
            anchor.y = obj.y
            break
        end
    end

    local shape
    for _, obj in ipairs(objects) do
        if obj.type == "anchor" then
            -- already taken care of
        elseif obj.type == "" then
            -- collision shape
            local new_shape = _tiled_shape_to_whammo_shape(obj, anchor)

            if shape then
                if not shape:isa(whammo_shapes.MultiShape) then
                    shape = whammo_shapes.MultiShape(shape)
                end
                shape:add_subshape(new_shape)
            else
                shape = new_shape
            end
        else
            -- FIXME maybe need to return a table somehow, because i want to keep this for wire points?
            error(
                ("Don't know how to handle shape type %s on tile %d from %s")
                :format(obj.type, tileid, self.path))
        end
    end

    return shape, anchor
end

--------------------------------------------------------------------------------
-- TiledMapLayer
-- Thin wrapper around a Tiled JSON layer.

local TiledMapLayer = Object:extend()

function TiledMapLayer:init(raw_layer)
    self.raw = raw_layer

    self.name = raw_layer.name
    self.width = raw_layer.width
    self.height = raw_layer.height

    self.type = raw_layer.type
    self.objects = raw_layer.objects
    self.data = raw_layer.data

    self.submap = self:prop('submap')
end

function TiledMapLayer:prop(key)
    if not self.raw.properties then
        return nil
    end
    local value = self.raw.properties[key]
    -- TODO this would be a good place to do type-casting based on the...  type
    return value
end

--------------------------------------------------------------------------------
-- TiledMap

local TiledMap = Object:extend{
    player_start = nil,
}

function TiledMap:init(path, resource_manager)
    self.raw = strict_json_decode(love.filesystem.read(path))

    -- Copy some basics
    self.tilewidth = self.raw.tilewidth
    self.tileheight = self.raw.tileheight
    self.width = self.raw.width * self.tilewidth
    self.height = self.raw.height * self.tileheight

    -- Load tilesets
    self.tiles = {}
    for _, tilesetdef in pairs(self.raw.tilesets) do
        local tileset
        if tilesetdef.source then
            -- External tileset; load it
            local tspath = relative_path(path, tilesetdef.source)
            tileset = resource_manager:get(tspath)
            if not tileset then
                tileset = TiledTileset(tspath, nil, resource_manager)
                resource_manager:add(tspath, tileset)
            end
        else
            tileset = TiledTileset(path, tilesetdef, resource_manager)
        end

        -- TODO spacing, margin
        local firstgid = tilesetdef.firstgid
        for relid = 0, tileset.tilecount - 1 do
            -- TODO gids use the upper three bits for flips, argh!
            -- see: http://doc.mapeditor.org/reference/tmx-map-format/#data
            -- also fix below
            self.tiles[firstgid + relid] = {
                tileset = tileset,
                tilesetid = relid,
            }
        end
    end

    -- Load layers
    self.layers = {}
    for _, raw_layer in ipairs(self.raw.layers) do
        local layer = TiledMapLayer(raw_layer)
        table.insert(self.layers, layer)
        if layer.type == 'imagelayer' then
            -- FIXME doesn't belong here...  does it?
            local imgpath = relative_path(path, layer.raw.image)
            layer.image = resource_manager:load(imgpath)
        end
    end

    -- Detach any automatic actor tiles
    -- TODO also more explicit actors via object layers probably
    self.actor_templates = {}
    for _, layer in ipairs(self.layers) do
        -- TODO this is largely copy/pasted from below
        -- FIXME i think these are deprecated for layers maybe?
        local width, height = layer.width, layer.height
        if layer.type == 'tilelayer' then
            local data = layer.data
            for t = 0, width * height - 1 do
                local gid = data[t + 1]
                local tile = self.tiles[gid]
                -- TODO lol put this in the tileset jesus
                -- TODO what about the tilepropertytypes
                if tile then
                    local proptable = tile.tileset.raw.tileproperties
                    if proptable then
                        local props = proptable[tile.tilesetid]
                        if props and props.actor then
                            local ty, tx = util.divmod(t, width)
                            table.insert(self.actor_templates, {
                                name = props.actor,
                                submap = layer.submap,
                                position = Vector(
                                    tx * self.raw.tilewidth,
                                    (ty + 1) * self.raw.tileheight - tile.tileset.raw.tileheight),
                            })
                            data[t + 1] = 0
                        end
                    end
                end
            end
        elseif layer.type == 'objectgroup' then
            for _, object in ipairs(layer.objects) do
                if object.type == 'player start' then
                    self.player_start = Vector(object.x, object.y)
                end
            end
        end
    end
end

function TiledMap:add_to_collider(collider, submap_name)
    -- TODO injecting like this seems...  wrong?  also keeping references to
    -- the collision shapes /here/?  this object should be a dumb wrapper and
    -- not have any state i think.  maybe return a structure of shapes?
    -- or, alternatively, create shapes on the fly from the blockmap...?
    if not self.shapes then
        self.shapes = {}
    end
    for _, layer in ipairs(self.layers) do
        if layer.type == 'tilelayer' and layer.submap == submap_name then
            local width, height = layer.width, layer.height
            local data = layer.data
            for t = 0, width * height - 1 do
                local gid = data[t + 1]
                local tile = self.tiles[gid]
                if tile then
                    -- TODO could just create this once and then clone it
                    local shape = tile.tileset:get_collision(tile.tilesetid)
                    if shape then
                        local ty, tx = util.divmod(t, width)
                        shape:move(
                            tx * self.raw.tilewidth,
                            (ty + 1) * self.raw.tileheight - tile.tileset.raw.tileheight)
                        self.shapes[shape] = true
                        collider:add(shape)
                    end
                end
            end
        elseif layer.type == 'objectgroup' and layer.submap == submap_name then
            for _, obj in ipairs(layer.objects) do
                if obj.type == 'collision' then
                    local shape = _tiled_shape_to_whammo_shape(obj, Vector.zero)
                    self.shapes[shape] = true
                    collider:add(shape)
                end
            end
        end
    end
end

-- Draw the whole map
function TiledMap:draw(layer_name, origin, width, height)
    -- TODO origin unused.  is it in tiles or pixels?
    local tw, th = self.raw.tilewidth, self.raw.tileheight
    for _, layer in pairs(self.layers) do
        if layer.name == layer_name then
            if layer.type == 'tilelayer' then
                local width, height = layer.width, layer.height
                local data = layer.data
                for t = 0, width * height - 1 do
                    local gid = data[t + 1]
                    if gid ~= 0 then
                        local tile = self.tiles[gid]
                        local ty, tx = util.divmod(t, width)
                        -- TODO don't draw tiles not on the screen
                        love.graphics.draw(
                            tile.tileset.image,
                            tile.tileset.quads[tile.tilesetid],
                            -- convert tile offsets to pixels
                            tx * tw,
                            (ty + 1) * th - tile.tileset.raw.tileheight,
                            0, 1, 1)
                    end
                end
            elseif layer.type == 'imagelayer' then
                love.graphics.draw(layer.image, layer.raw.offsetx, layer.raw.offsety)
            end
        end
    end
end

return {
    TiledMap = TiledMap,
    TiledTileset = TiledTileset,
}
