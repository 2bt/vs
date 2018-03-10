function new_bone(x, y, ang, poly)
	local b = {
		kids = {},
		x    = x or 0,
		y    = y or 0,
		ang  = ang or 0,
		poly = poly or {},
		keyframes = {},
	}
	return b
end


function add_bone(p, k)
	table.insert(p.kids, k)
	k.parent = p
end


function delete_bone(b)
	if not b.parent then return b end
	local p = b.parent
	for i, k in ipairs(p.kids) do
		if k == b then
			table.remove(p.kids, i)
			break
		end
	end
	return p
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


local root_bone
function init_bone()
	root_bone = new_bone()
	--add_bone(root_bone, new_bone(200, 0, 0))
	--add_bone(root_bone.kids[1], new_bone(-30, 100, 0))
	--add_bone(root_bone.kids[1].kids[1], new_bone(70, 0, 0))
	update_bone(root_bone)
	return root_bone
end


function for_all_bones(func)
	local function visit(b, func)
		if func(b) then return true end
		for _, k in ipairs(b.kids) do
			if visit(k, func) then return true end
		end
	end
	visit(root_bone, func)
end


function set_bone_frame(frame)
	for_all_bones(function(b)
		local k1, k2
		for i, k in ipairs(b.keyframes) do
			if k[1] < frame then
				k1 = k
			end
			if k[1] >= frame then
				k2 = k
				break
			end
		end
		if k1 and k2 then
			local l = (frame - k1[1]) / (k2[1] - k1[1])
			local function lerp(i) return k1[i] * (1 - l) + k2[i] * l end
			b.x   = lerp(2)
			b.y   = lerp(3)
			b.ang = lerp(4)
		elseif k1 or k2 then
			local k = k1 or k2
			b.x   = k[2]
			b.y   = k[3]
			b.ang = k[4]
		end
	end)
	update_bone(root_bone)
end


function insert_bone_keyframe(frame)
	for_all_bones(function(b)
		local kf
		for i, k in ipairs(b.keyframes) do
			if k[1] == frame then
				kf = k
				break
			end
			if k[1] > frame then
				kf = { frame }
				table.insert(b.keyframes, i, kf)
				break
			end
		end
		if not kf then
			kf = { frame }
			table.insert(b.keyframes, kf)
		end
		kf[2] = b.x
		kf[3] = b.y
		kf[4] = b.ang
	end)
end
function delete_bone_keyframe(frame)
	for_all_bones(function(b)
		for i, k in ipairs(b.keyframes) do
			if k[1] == frame then
				table.remove(b.keyframes, i)
				break
			end
		end
	end)
end
local keyframe_buffer = {}
function copy_bone_keyframe(frame)
	keyframe_buffer = {}
	for_all_bones(function(b)
		for _, k in ipairs(b.keyframes) do
			if k[1] == frame then
				table.insert(keyframe_buffer, { k[2], k[3], k[4] })
				break
			end
		end
	end)
end
function paste_bone_keyframe(frame)
	local i = 1
	for_all_bones(function(b)
		local q = keyframe_buffer[i]
		if not q then return true end
		i = i + 1
		local kf
		for i, k in ipairs(b.keyframes) do
			if k[1] == frame then
				kf = k
				break
			end
			if k[1] > frame then
				kf = { frame }
				table.insert(b.keyframes, i, kf)
				break
			end
		end
		if not kf then
			kf = { frame }
			table.insert(b.keyframes, kf)
		end
		kf[2] = q[1]
		kf[3] = q[2]
		kf[4] = q[3]
	end)
	set_bone_frame(frame)
end


function load_bones(name)
	local file = io.open(name)
	local str = file:read("*a")
	file:close()
	local data = loadstring("return " .. str)()
	local function load(d)
		local b = new_bone(d.x, d.y, d.ang, d.poly)
		b.keyframes = d.keyframes
		for _, k in ipairs(d.kids) do
			add_bone(b, load(k))
		end
		return b
	end
	root_bone = load(data)
	update_bone(root_bone)
	return root_bone
end


function save_bones(name)
	local function save(b)
		local data = {
			x         = b.x,
			y         = b.y,
			ang       = b.ang,
			poly      = b.poly,
			keyframes = b.keyframes,
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
end
