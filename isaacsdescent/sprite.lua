local anim8 = require 'vendor.anim8'
local Class = require 'vendor.hump.class'

--------------------------------------------------------------------------------
-- Sprite
-- Contains a number of 'poses', each of which is an anim8 animation.  Can
-- switch between them and draw with a simplified API.

local Sprite = Class{}
local SpriteInstance  -- defined below

-- TODO this restricts a single sprite to only pull frames from a single image,
-- which isn't unreasonable, but also seems like a needless limitation
-- TODO seems like this could be wired in with Tiled?  apparently Tiled can
-- even define animations, ha!
function Sprite:init(image, tilewidth, tileheight, x, y, margin)
    self.image = image
    self.grid = anim8.newGrid(
        tilewidth, tileheight,
        image:getWidth(), image:getHeight(),
        x, y, margin)
    self.poses = {}
    self.default_pose = nil
end

function Sprite:add_pose(name, grid_args, durations, endfunc)
    -- TODO this is pretty hokey, but is a start at support for non-symmetrical
    -- characters.  maybe add an arg to set_pose rather than forcing the caller
    -- to do this same name mangling though?
    local rightname = name .. '/right'
    local leftname = name .. '/left'
    assert(not self.poses[rightname], ("Pose %s already exists"):format(rightname))
    local anim = anim8.newAnimation(
        self.grid(unpack(grid_args)), durations, endfunc)
    self.poses[rightname] = anim
    self.poses[leftname] = anim:clone():flipH()
    if not self.default_pose then
        self.default_pose = rightname
    end
end

-- A Sprite is a definition; call this to get an instance with state, which can
-- draw itself and remember its current pose
function Sprite:instantiate()
    return SpriteInstance(self)
end

SpriteInstance = Class{}

function SpriteInstance:init(sprite)
    self.sprite = sprite
    self.scale = 1
    self.pose = nil
    self._pending_pose = nil
    self.anim = nil
    -- TODO this doesn't check that the default pose exists
    self:_set_pose(sprite.default_pose)
end

-- Schedule the given pose to replace the current pose on the next update()
-- call.  (This way, calling set_pose() followed by update() doesn't skip the
-- first frame of the new pose.)
-- Changing to the current pose is a no-op.
function SpriteInstance:set_pose(pose)
    if pose == self.pose then
        self._pending_pose = nil
    else
        assert(self.sprite.poses[pose], ("No such pose %s"):format(pose))
        self._pending_pose = pose
    end
end

function SpriteInstance:_set_pose(pose)
    -- Internal method that actually changes the pose.  Doesn't check that the
    -- pose exists.
    self.pose = pose
    self.anim = self.sprite.poses[pose]:clone()
    self._pending_pose = nil
end

function SpriteInstance:set_scale(scale)
    self.scale = scale
end

function SpriteInstance:update(dt)
    if self._pending_pose then
        self:_set_pose(self._pending_pose)
    else
        self.anim:update(dt)
    end
end

function SpriteInstance:draw_at(point)
    -- TODO hm, how do i auto-batch?  shame there's nothing for doing that
    -- built in?  seems an obvious thing
    self.anim:draw(self.sprite.image, point.x, point.y, 0, self.scale, self.scale)
end


return Sprite
