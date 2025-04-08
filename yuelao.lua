--[[
yue lao

obj:
	:msg()
	:rcv()
	:ins()
	:rmv()
	.children
	.parent
	.priority {
		draw
		update
		etc
	}

system:
	:init()
	:new(obj)
	:rmv(obj)
	.api -- can be anything, just what's public
	priority {}


system list:
	spatial
	physics
	msg
	hierarchy
	input
	gid

system callbacks/etc:
	:hook(game) -- gets full access to game to do whatever
	.api -- set as a metatable of game when hooked
	.dependencies -- table of dependencies to look for in game._hooks, to make sure the order is right





Game:
	.blueprint
	.system

	.config {
		display {
			w
			h
			type
		}
	}

systems have hooks for object init, update etc
allow for adding parameters to callbacks

--]]



local function deep_merge(parent, child)
    -- Collect numeric keys from child and sort them
    local numericKeys = {}
    for k in pairs(child) do
        if type(k) == "number" then
            table.insert(numericKeys, k)
        end
    end
    table.sort(numericKeys)

    -- Process sorted numeric keys to append values to parent's array
    for _, k in ipairs(numericKeys) do
        local value = child[k]
        if type(value) == "table" then
            local nextIndex = #parent + 1
            if type(parent[nextIndex]) ~= "table" then
                parent[nextIndex] = {}
            end
            deep_merge(parent[nextIndex], value)
        else
            table.insert(parent, value)
        end
    end

    -- Process non-numeric keys, merging as before
    for key, value in pairs(child) do
        if type(key) ~= "number" then
            if type(value) == "table" then
                if type(parent[key]) ~= "table" then
                    parent[key] = {}
                end
                deep_merge(parent[key], value)
            else
                parent[key] = value
            end
        end
    end
end


return function(config)
	local default_config = {
		hook_callbacks = true,
		systems = {}
	}
	setmetatable(config, {__index = default_config})
	local Game = {
		_systems = {},
		_callbacks = {},
		_hooks = {},
		_helper = {deep_merge = deep_merge}
	}

	for _,system in ipairs(config.systems) do
		local dependencies_met = true
		for _,dependency in ipairs(system.dependencies or {}) do
			if not Game._systems[dependency] then dependencies_met = false end
		end
		if dependencies_met then
			if system.init then
				deep_merge(Game, system.init(Game) or {})
				Game._systems[system.id] = system
			end
		end
	end

	function Game._callbacks.update(dt)
		for _,update_func in ipairs(Game._cache.update_sys) do
			update_func(dt)
		end
	end



	return Game
end -- end yuelao