local window = {
	id = "window"
}

function window.init(Game)
	Game.display = Game.display or {}
	local default_config = {
		w = 1920,
		h = 1080,
		mode = "fit",
		resizeable = true
	}
	setmetatable(Game.display, {__index = default_config})

	love.window.setMode(Game.display.w,Game.display.h, { resizable = Game.display.resizeable })
	--[[
	function love.resize(w,h)
		Root.scale = math.min(h/Game.display.h, w/Game.display.w)
		Root.y = (h - (Game.display.h * Root.scale)) / 2
		Root.x = (w - (Game.display.w * Root.scale)) / 2
	end
	--]]
end

return window