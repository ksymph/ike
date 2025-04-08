local blueprints = {
	id = "blueprints"
}

local function chain_metatables(metatables)
	local previous = nil
	for i = #metatables, 1, -1 do
		local current = metatables[i]
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

function blueprints.init(Game)
	local blueprints_metatable = {
		__newindex = function(t, blueprint_name, blueprint)
			local new_blueprint = {}

			if blueprint.extends then
				local blueprints = {}
				for _, blueprint_id in ipairs(blueprint.extends) do
					table.insert(blueprints, Game.blueprints[blueprint_id])
				end
				local merged = chain_metatables(blueprints)
				setmetatable(new_blueprint, { __index = merged })
			end

			for k,v in pairs(blueprint) do
				if k ~= "extends" then
					if type(v) == "table" then
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
			end
			rawset(t, blueprint_name, new_blueprint)
		end
	}

	Game.blueprints = {}
	setmetatable(Game.blueprints, blueprints_metatable)

	Game.blueprints.default = {}

	hooks = {
		obj_ins = {
			function(obj)
				local blueprints = {}
				for _,blueprint_id in ipairs(obj.extends or {}) do
					table.insert(blueprints, Game.blueprints[blueprint_id])
				end
				table.insert(blueprints, Game.blueprints.default)
				table.insert(blueprints, getmetatable(obj).__index)
				local blueprint_merged = chain_metatables(blueprints)
				setmetatable(obj, {__index = blueprint_merged})
			end
		}
	}

	return {_helper = {chain_metatables = chain_metatables}, _hooks = hooks}
end

return blueprints