Game = require "ike"
Root = Game.root

love.window.setMode(1920,1080, { resizable = true, highdpi = true, usedpiscale = false })
function love.resize(w,h)
	Root.scale = math.min(h/1080, w/1920)
	Root.y = (h - (1080 * Root.scale)) / 2
	Root.x = (w - (1920 * Root.scale)) / 2
end


Game.blueprints.vbar = {
	rot = -0.57,
	draw = function(self)
		love.graphics.setColor(1,1,1, self.light)
		love.graphics.rectangle("fill", 0,0, 64,256)
	end,
	update = function(self, dt)
		self.x = self.x > 952 and -128 or self.x + 0
		self.y = self.y > 512 and -320 or self.y + 0
		if self.id == 5 and self.x > 952 then self:rmv() end
		--print(self.gid)
	end
}

Root:ins {
	rot = 0,
	extends = "vbar"
}
Root:ins {
	rot = 0,
	extends = "vbar",
	x = 1856,
	update = function() end
}
Root:ins {
	rot = 0,
	extends = "vbar",
	x = 1856,
	y = 824,
	update = function() end
}

local vbar_container = Root:ins("vbar_container",
	{
		y = 32,
		children = {
			{extends = "vbar",light = 255, x = 255, y=100, children = {{extends = "vbar",light = 255, x = 5, y=5}}}
		}
	}
)

for i=1,8 do
	vbar_container:ins({light = i/8, x = i*96, y=i*32, extends = "vbar"})
end

love.graphics.setDefaultFilter('nearest', 'nearest')

Root:ins {
	draw = function()
		love.graphics.setColor(1,1,1,1)
		local target = Game.gid["root.vbar_container.3"] or {x=0}
		love.graphics.print("Hello world!", target.x, 256)
	end
}
