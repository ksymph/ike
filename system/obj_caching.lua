local obj_caching = {
	id = "obj_caching",
	dependencies = {"hierarchy", "gid"}
}

local function flatten(root, key)
	local list = {}
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

	drill(root)
	return list
end

function obj_caching.init(Game)
	local hooks = {}
	hooks.obj_die = {function(obj)
		Game._cache.rebuild = true
	end}
	hooks.obj_init = {function(obj)
		Game._cache.rebuild = true
	end}

	local function update(dt)
		if Game._cache.rebuild then
			Game._cache.update_obj = flatten(Game.root, "update")
			Game._cache.draw_obj = flatten(Game.root, "update")

			Game._cache.rebuild = false
		end
		for _,gid in ipairs(Game._cache.update_obj or {}) do
			Game.get[gid]:update(dt)
		end
	end


	return {_hooks = hooks, _cache = {update_sys = {update}}}
end

return obj_caching