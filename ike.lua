local Game = {
	blueprints = {},
	gid = {},
	_rmv_cache = {},
	_add_cache = {},
	_upd_cache = {},
	_draw_cache = {}
}

-- loops get_gid calls to parents
-- parents need _get_gid method
-- returns a gid in format "parent.child.grandchild"
local function get_gid(self)
	local gid = self.id
	if self.parent then gid = self.parent:_get_gid() .. "." .. gid end
	Game.gid[gid] = self
	return gid
end

-- accepts an array of tables
-- chains metatable indices to return a table that
-- gives access to all tables when used as __index
-- priority is the order in the inital array, checks first then second etc
-- todo: right now, only the highest-level draw/update method is called
-- draw/update methods should be collected here then cached in Game to fix that
local function merge_blueprints(blueprints)
	local previous = nil
	for i = #blueprints, 1, -1 do
		local current = blueprints[i]
		local prev = previous
		previous = setmetatable({}, {
			__index = function(_, key)
				local value = current[key]
				if value ~= nil then
					return value
				else
					return prev and prev[key]
				end
			end
		})
	end
	return previous
end

-- usage: obj:ins(child) or obj:ins(id, child)
-- note: child can have 'extends' field
-- this can be a string, or an array of strings of registered blueprints
-- todo: batching. children should be added to a subtable in Game
-- then added all at once at the start/end of a frame
local function add_child(parent, a, b)

	-- properly assign child and id based on types
	local child, id
	if type(a) == "string" then
		id = a or #parent.children + 1
		child = b or {}
	else
		child = a or {}
		id = #parent.children + 1
	end

	-- assemble a merged blueprint from child's extend field
	-- todo: caching merged blueprints? could use an id system like gid
	local blueprints = {}
	local child_blueprints = type(child.extends) == "string" and {child.extends}
		or type(child.extends) == "table" and child.extends
		or {}
	for _,blueprint_id in ipairs(child_blueprints) do
		table.insert(blueprints, Game.blueprints[blueprint_id])
	end
	table.insert(blueprints, Game.blueprints.default)
	local blueprint_merged = merge_blueprints(blueprints)

	-- assign child's properties and whatnot
	-- note: the order here is important
	child.id = id
	child.parent = parent
	setmetatable(child, {__index = blueprint_merged})
	child.gid = get_gid(child)

	-- init child, add grandchildren
	-- todo: fix adding grandchildren
	if child.init then child:init() end
	local grandchildren = {}
	for gc_id,grandchild in pairs(child.children) do
		grandchildren[gc_id] = grandchild
	end
	child.children = {}
	for gc_id,grandchild in pairs(grandchildren) do
		--add_child(child, grandchild)
		-- what the fuck is going on here
	end

	parent.children[child.id] = child
	return child
end

-- recursively iterates through a table and its .children to create
-- a 1d array, ordered by the provided key's value
-- order is relative to parent
-- to_push_pop is whether to put in "push" and "pop" for draw calls
local function flatten(root, key, to_push_pop)
	local flat_obj = _cumulative or {}
	local list = {}
	local function drill(base, key)
		if to_push_pop then table.insert(list, "push") end
		table.insert(list, base.gid)
		local children = {}
		if base.children then
			for _,obj in pairs(base.children) do
				table.insert(children, obj)
			end
		end

		if #children > 0 then
			table.sort(children, function(a,b)
				return a[key] < b[key]
			end)
			for _,obj in ipairs(children) do
				drill(obj, key)
			end
		end
		if to_push_pop then table.insert(list, "pop") end

	end

	drill(root, key)
	return list
end

-- self explanatory, really
function Game.rebuild_cache()
	Game._draw_cache = flatten(Game.root, "draw_priority", true)
	Game._upd_cache = flatten(Game.root, "update_priority")
end

-- the actual object removal function
-- should only be called between frames
local function remove_object(self)
	for _,child in pairs(self.children) do
		remove_object(child)
	end
	Game.gid[self.gid] = nil
	self.parent.children[self.id] = nil
	self = nil
end

-- todo: clean this stuff up
-- adds objects to the _rmv_cache
-- to be removed between frames
local function to_remove(self)
	table.insert(Game._rmv_cache, self)
end
local function to_remove_child(self, id)
	if child_id == "*" then
		for _,child in pairs(self.children) do
			table.insert(Game._rmv_cache, child)
		end
	else
		table.insert(Game._rmv_cache, self.children[id])
	end
end

-- base 'object' metatable
-- inherited by everything
Game.blueprints.default = {
	x = 0,
	y = 0,
	rot = 0,
	scale = 1,
	children = {},
	ins = add_child,
	rmv = to_remove,
	rmv_child = to_remove_child,
	draw_priority = 1,
	update_priority = 1,
	_get_gid = get_gid
}


-- irrelevant in its current state, but
-- todo: inheritance for blueprints
-- remember to use merge_blueprints
--[[
setmetatable(Game.blueprints, {
	__newindex = function(blueprints, id, blueprint)
		setmetatable(blueprint, {__index = Game.blueprints.default})
		rawset(blueprints, id, blueprint)
	end
})
--]]




-- todo: fix this fucking mess
-- todo: add other love callbacks
function love.draw()
	Game.rebuild_cache()

	--local offset_x, offset_y = 0,0
	for _,id in ipairs(Game._draw_cache) do
		--break
		if id == "push" then
			love.graphics.push()
			--print("pushing")
		elseif id == "pop" then
			love.graphics.pop()
			--print("popping")
		else
			local obj = Game.gid[id]
			--print("translating to",obj.x,obj.y)
			love.graphics.translate(obj.x, obj.y)
			love.graphics.rotate(obj.rot)
			love.graphics.scale(obj.scale)
			--offset_x, offset_y = obj.x, obj.y
			if obj.draw then
				obj:draw()
			end
		end
	end
	--]]
end

function love.update(dt)
	for _,obj in pairs(Game.gid) do
		--print(obj.gid)
		if obj.update then obj:update(dt) end
	end
	for _, obj in ipairs(Game._rmv_cache) do
		local obj_gid = obj.gid
		remove_object(obj)
		Game.gid[obj_gid] = nil
	end
end


-- idk why but this needs to be a local variable, then metatable set, then added to Game
-- can't just do Game.root = {id blah blah for some reason
local root = {
	id = "root",
	gid = "root"
}
setmetatable(root, { __index = Game.blueprints.default })
Game.root = root
return Game