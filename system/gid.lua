local gid = {
	id = "gid"
}


function gid.init(Game)
	local function assign_gid(obj)
		obj.gid = obj.parent and obj.parent.gid .. "." .. obj.id
			or obj.id
		Game.get[obj.gid] = obj
	end
	local function clear_obj(obj)
		Game.get[obj.gid] = nil
	end
	return {get = {}, _hooks = {obj_init = {assign_gid}, obj_die = {clear_obj}}}
end


return gid