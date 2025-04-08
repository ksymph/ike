yuelao = require "yuelao"
local systems = {
	require "system.blueprints",
	require "system.hierarchy",
	require "system.gid",
	require "system.obj_caching",
	require "system.window"
}

Game = yuelao({systems = systems})

Game.root:ins("foo", {update = function(self, dt) print(dt) end})


function love.update(dt)
	Game._callbacks.update(dt)
	local foo = Game.root.children.foo
	--print(foo.update)
	--for k,v in pairs(Game.root.children) do print(k,v.gid) end
	--if Game.root.children.foo then Game.root.children.foo:rmv() end
end
