local Game = {
	blueprints = {},
	gid = {},
	_cache = {
		update = {},
		draw = {}
	},
	_queue = {
		remove = {},
		add = {},
		message = {},
		pause = {}
	}
}

local callbacks = {}
-- recursively loops get_gid through parents
-- parents need _get_gid method
-- returns a gid in format "parent.child.grandchild"
local function get_gid(self)
	local gid = self.id
	if self.parent then
		gid = self.parent.gid .. "." .. gid
	end
	Game.gid[gid] = self
	return gid
end

-- accepts an array of tables
-- chains metatable indices to return a table that
-- gives access to all tables when used as __index
-- priority is the order in the inital array, checks first then second etc
-- todo: right now, only the highest-level draw/update method is called
-- draw/update methods should be collected here then cached to fix that
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


-- recursively iterates through a table and its .children to create
-- a 1d array, ordered by the provided key's value
-- order is relative to parent
-- to_push_pop is whether to put in "push" and "pop" for draw calls
-- todo: check object parameters to eliminate unnecessary pushes/pops
-- if x/y/rot/scale are the same then don't push pop
local function flatten(root, key)
	local list = {}

	local prev = {
		x = 0,
		y = 0,
		rot = 0,
		scale = 0
	}

	local function drill(base)
		if base[key] then table.insert(list, base.gid) end
		local children = {}
		if base.children then
			for _,obj in pairs(base.children) do
				table.insert(children, obj)
			end
		end

		if #children > 0 then
			table.sort(children, function(a,b)
				return a.priority[key] < b.priority[key]
			end)
			for _,obj in ipairs(children) do
				drill(obj, key)
			end
		end
	end
	local function drill_draw(base)
		local to_push_pop = false
		if (prev.x ~= base.x) or
			(prev.y ~= base.y) or
			(prev.rot ~= base.rot) or
			(prev.scale ~= base.scale) then
				prev.x = base.x
				prev.y = base.y
				prev.rot = base.rot
				prev.scale = base.scale
				to_push_pop = true
		end
		if to_push_pop then table.insert(list, "push") end
		if base[key] or to_push_pop then table.insert(list, base.gid) end
		local children = {}
		if base.children then
			for _,obj in pairs(base.children) do
				table.insert(children, obj)
			end
		end

		if #children > 0 then
			table.sort(children, function(a,b)
				return a.priority[key] < b.priority[key]
			end)
			for _,obj in ipairs(children) do
				drill_draw(obj, key)
			end
		end
		if to_push_pop then table.insert(list, "pop") end
	end


	if key == "draw" then drill_draw(root)
	else drill(root) end
	return list
end

-- self explanatory, really
function Game.rebuild_cache()
	for callback_name,_ in pairs(callbacks) do
		Game._cache[callback_name] = flatten(Game.root, callback_name)
		--for k,v in pairs(Game._cache[callback_name]) do print(k,v) end
	end
end

-- the actual object removal function
local function remove_object(self)
	for _,child in pairs(self.children) do
		remove_object(child)
	end
	Game.gid[self.gid] = nil
	self.parent.children[self.id] = nil
end

-- adds objects to the _rmv_queue
-- to be removed between frames
local function to_remove(self)
	table.insert(Game._queue.remove, self)
end
local function to_remove_child(self, id)
	if child_id == "*" then
		for _,child in pairs(self.children) do
			table.insert(Game._queue.remove, child)
		end
	else
		table.insert(Game._queue.remove, self.children[id])
	end
end

-- note: child can have 'extends' field
-- this can be a string, or an array of strings of registered blueprints
local function add_object(object)
	if not object.id then
		object.id = #object.parent.children + 1
		object.gid = get_gid(object)
	end

	if object.init then object:init() end

	object.parent.children[object.id] = object

end

local function pause_object(pause_recipe)
	local obj = Game.gid[pause_recipe.target_id]
	local target_parameter_list = {}
	if target_parameter == "*" then
		for k,v in pairs(obj.pause) do
			target_parameter_list[k] = v
		end
	else
		target_parameter_list[pause_recipe.target_parameter] = obj.pause[pause_recipe.target_parameter]
	end

	for k,v in pairs(target_parameter_list) do
		obj.pause[k] = type(pause_recipe.target_state) == "boolean" and pause_recipe.target_state
			or not obj.pause[k]
	end
end


local function to_pause(self, target_parameter, target_state)
	table.insert(Game._queue.pause, {
		target_id = self.gid,
		target_parameter = target_parameter or "*",
		target_state = target_state
	})
end

-- :to_add([id], obj)
local function to_add(parent, a, b)
	-- infer child and id based on types
	local child, id
	if type(a) == "string" or type(a) == "number" then
		id = a or #parent.children + 1
		child = b or {}
	else
		child = a or {}
		id = nil
	end

	-- assemble a merged blueprint from child's extend field
	-- todo: caching merged blueprints? could use an id system like gid
	local blueprints = {}
	for _,blueprint_id in ipairs(child.extends or {}) do
		table.insert(blueprints, Game.blueprints[blueprint_id])
	end
	table.insert(blueprints, Game.blueprints.default)
	local blueprint_merged = merge_blueprints(blueprints)

	-- assign child's properties and whatnot
	-- note: the order here is important
	child.parent = parent
	if id then
		child.id = id
		child.gid = get_gid(child)
	end
	if not child.children then child.children = {} end
	if not child.priority then
		child.priority = {
			draw = 1,
			update = 1
		}
	end
	--[[
	if not child.pause then
		local pause_table = {}
		for k,_ in pairs(callbacks) do pause_table[k] = false end
		child.pause = setmetatable(pause_table, {
			__call = to_pause
		})
	end
	--]]


	setmetatable(child, {__index = blueprint_merged})


	-- check for grandchildren
	for gc_id,grandchild in pairs(child.children) do
		to_add(child, gc_id, grandchild)
	end


	table.insert(Game._queue.add, child)
	return child
end

local function send_message(self, recipient, message)
	local recipient_gid = type(recipient) == "table" and recipient.gid or recipient
	table.insert(Game._queue.message, {sender = self.gid, recipient = recipient_gid, contents = message})
end


setmetatable(Game.blueprints, {
	__newindex = function(t, blueprint_name, blueprint)
		local new_blueprint = {}
		for k,v in pairs(blueprint) do
			if k == "extends" then
				local blueprints = {}
				for _,blueprint_id in ipairs(v) do
					table.insert(blueprints, Game.blueprints[blueprint_id])
				end
				local blueprint_merged = merge_blueprints(blueprints)
			elseif type(v) == "table" then
				local function drill(base)
					local assembled_table = {}
					for key,val in pairs(base) do
						if type(val) == "table" then
							assembled_table[key] = drill(val)
						else
							assembled_table[key] = val
						end
					end
					return assembled_table
				end
				new_blueprint[k] = drill(v)
			else
				new_blueprint[k] = v
			end
		end
		rawset(t, blueprint_name, new_blueprint)
	end
})

-- base 'object' metatable
-- inherited by everything
Game.blueprints.default = {
	x = 0,
	y = 0,
	rot = 0,
	scale = 1,
	ins = to_add,
	rmv = to_remove,
	rmv_child = to_remove_child,
	msg = send_message
}




-- todo: add other love callbacks
-- keypressed, etc
callbacks = {
	update = function(dt)
		local to_rebuild = false

		-- pause objects
		for _,pause_recipe in ipairs(Game._queue.pause) do
			pause_object(pause_recipe)
			to_rebuild = true
		end
		Game._queue.pause = {}

		-- call object updates
		for _,id in pairs(Game._cache.update) do
			local obj = Game.gid[id]
			if obj.update then obj:update(dt) end
		end

		-- clear objects in remove queue
		for _, obj in ipairs(Game._queue.remove) do
			local obj_gid = obj.gid
			remove_object(obj)
			Game.gid[obj_gid] = nil
			to_rebuild = true
		end
		Game._queue.remove = {}

		-- insert objects in add queue
		for _, obj in ipairs(Game._queue.add) do
			add_object(obj)
			to_rebuild = true
		end
		Game._queue.add = {}

		-- send messages
		for _,message in ipairs(Game._queue.message) do
			if Game.gid[message.recipient] and Game.gid[message.recipient].receive then
				Game.gid[message.recipient]:receive(message.sender, message.contents)
			end
		end
		Game._queue.message = {}


		if to_rebuild then Game.rebuild_cache() end
	end,

	draw = function()
		for _,id in ipairs(Game._cache.draw) do
			if id == "push" then love.graphics.push()
			elseif id == "pop" then love.graphics.pop()
			else
				local obj = Game.gid[id]
				-- todo: don't translate/scale/etc if not necessary
				love.graphics.translate(obj.x, obj.y)
				love.graphics.rotate(obj.rot)
				love.graphics.scale(obj.scale)
				if obj.draw then
					obj:draw()
				end
			end
		end
	end
}





for k,v in pairs(callbacks) do
	love[k] = v
end




-- idk why but this needs to be a local variable, then metatable set, then added to Game
-- can't just do Game.root = {id blah blah for some reason
local root = {
	id = "root",
	gid = "root",
	children = {},
	priority = {}
}
setmetatable(root, { __index = Game.blueprints.default })
Game.root = root
Game.gid.root = root
return Game