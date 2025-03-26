Game = require "ike"
local Root = Game.root

Root.scale = 2
love.window.setMode(1920,1080)


Game.blueprints.vbar = {
	rot = -0.57,
	draw = function(self)
		love.graphics.setColor(1,1,1, self.light)
		love.graphics.rectangle("fill", 0,0, 64,256)
	end,
	update = function(self, dt)
		self.x = self.x > 952 and -128 or self.x + 2
		self.y = self.y > 512 and -320 or self.y + 1
		if self.id == 5 and self.x > 952 then self:rmv() end
	end
}


local vbar_container = Root:ins("vbar_container", {y = 32})
for i=1,8 do
	vbar_container:ins({light = i/8, x = i*96, y=i*32, extends = "vbar"})
end


Root:ins {
	draw = function()
		love.graphics.setColor(1,1,1,1)
		love.graphics.print("Hello world!", Game.gid["root.vbar_container.3"].x, 256)
	end
}
