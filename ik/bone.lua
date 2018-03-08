function new_bone(x, y, ang, poly)
	local b = {
		kids = {},
		x    = x,
		y    = y,
		ang  = ang,
		poly = poly or { -25, -25, 25, -25, 25, 25, -25, 25 }
	}
	return b
end


function add_bone(p, k)
	table.insert(p.kids, k)
	k.parent = p
end


function update_bone(b)
	local p = b.parent or {
		global_x = 0,
		global_y = 0,
		global_ang = 0,
	}

	local si = math.sin(p.global_ang)
	local co = math.cos(p.global_ang)

	b.global_x = p.global_x + b.x * co - b.y * si
	b.global_y = p.global_y + b.y * co + b.x * si
	b.global_ang = p.global_ang + b.ang

	for _, k in ipairs(b.kids) do
		update_bone(k)
	end
end


local root_bone = new_bone(0, 0, 0)
selected_bone   = root_bone


--add_bone(root_bone, new_bone(200, 0, 0))
--add_bone(root_bone.kids[1], new_bone(-30, 100, 0))
--add_bone(root_bone.kids[1].kids[1], new_bone(70, 0, 0))


update_bone(root_bone)


function for_all_bones(func)
	local function visit(b, func)
		if func(b) then return true end
		for _, k in ipairs(b.kids) do
			if visit(k, func) then return true end
		end
	end
	visit(root_bone, func)
end


function load_bones(name)
	local file = io.open(name)
	local str = file:read("*a")
	file:close()
	local data = loadstring("return " .. str)()
	local function load(d)
		local b = new_bone(d.x, d.y, d.ang, d.poly)
		for _, k in ipairs(d.kids) do
			add_bone(b, load(k))
		end
		return b
	end
	root_bone = load(data)
	selected_bone = root_bone

	update_bone(root_bone)
	print("bones loaded")
end


function save_bones(name)
	local function save(b)
		local data = {
			x = b.x,
			y = b.y,
			ang = b.ang,
			poly = b.poly,
			kids = {},
		}
		for _, k in ipairs(b.kids) do
			table.insert(data.kids, save(k))
		end
		return data
	end
	local data = save(root_bone)
	local file = io.open(name, "w")
	file:write(table.tostring(data) .. "\n")
	file:close()
	print("bones saved")
end
