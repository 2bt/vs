function new_bone(x, y, ang)
	local b = {
		kids = {},
		x    = x,
		y    = y,
		ang  = ang,
		poly = { 0, 0, 100, 0, 100, 50, 0, 50 }
	}
	table.insert(bones, b)
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


bones         = {}
root          = new_bone(0, 0, 0)
selected_bone = root

--add_bone(root, new_bone(200, 0, 0))
--add_bone(root.kids[1], new_bone(-30, 100, 0))
--add_bone(root.kids[1].kids[1], new_bone(70, 0, 0))


update_bone(root)


function load_bones(name)
	local file = io.open(name)
	local str = file:read("*a")
	file:close()
	local data = loadstring("return " .. str)()
	bones = {}
	root = nil
	for _, d in ipairs(data) do
		local b = new_bone(d.x, d.y, d.ang)
	end
	for i, b in ipairs(bones) do
		if data[i].p then
			add_bone(bones[data[i].p], b)
		else
			root = b
			selected_bone = b
		end
	end
	update_bone(root)
end


function save_bones(name)
	local data = {}
	for i, b in ipairs(bones) do
		data[i] = {
			x = b.x,
			y = b.y,
			ang = b.ang,
		}
		for j, p in ipairs(bones) do
			if p == b.parent then
				data[i].p = j
				break
			end
		end
	end
	local file = io.open(name, "w")
	file:write(table.tostring(data) .. "\n")
	file:close()
end
