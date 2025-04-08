local hierarchy = {
	id = "hierarchy"
}


hierarchy.init = function(Game)
	local obj_metatable = {}

	local hooks = {
		obj_ins = {},
		obj_rmv = {},
		obj_init = {},
		obj_die = {}
	}

	local function insert(obj)
		local id = obj.id or #obj.parent.children + 1
		obj.parent.children[id] = obj
		for _,init_func in ipairs(Game._hooks.obj_init) do
			init_func(obj)
		end
		if obj.init then obj:init() end
	end

	local function remove(obj)
		for _,child in ipairs(obj.children) do
			remove(child)
		end
		for _,die_func in ipairs(Game._hooks.obj_die) do
			die_func(obj)
		end
		if obj.die then obj:die() end
		obj.parent.children[obj.id] = nil
	end

	local function update(dt)
		for _,obj in ipairs(Game._queue.obj_ins) do
			insert(obj)
		end
		Game._queue.obj_ins = {}

		for _,obj in ipairs(Game._queue.obj_rmv) do
			remove(obj)
		end
		Game._queue.obj_rmv = {}
	end

	function obj_metatable.ins(parent, a, b)
		local child, id
		if b then
			id = a or parent and parent.children and #parent.children + 1
			child = b
		else
			child = a
			id = parent and parent.children and #parent.children + 1
		end
		child.id = id
		child.parent = parent
		child.children = {}
		setmetatable(child, {__index = obj_metatable})
		for _,ins_func in ipairs(Game._hooks.obj_ins) do
			ins_func(parent, child)
		end

		table.insert(Game._queue.obj_ins, child)

	end

	function obj_metatable.rmv(self, target)
		local target = target or self
		if type(target) == "table" then
			table.insert(Game._queue.obj_rmv, target)
		elseif target == "*" then
			for _,child in pairs(self.children) do
				table.insert(Game._queue.obj_rmv, child)
			end
		else
			-- if not table or *, then treat as gid. requires gid system
			table.insert(Game._queue.obj_rmv, Game.get[target])
		end
		for _,rmv_func in ipairs(Game._hooks.obj_rmv) do
			rmv_func(parent, child)
		end
	end

	Game.root = {
		id = "root",
		gid = "root",
		children = {}
	}

	setmetatable(Game.root, {__index = obj_metatable})

	return {_hooks = hooks, _queue = {obj_ins = {}, obj_rmv = {}}, _cache = {update_sys = {update}}}
end

return hierarchy