Bone = Object:new()
function Bone:init(x, y, ang)
	self.x         = x or 0
	self.y         = y or 0
	self.ang       = ang or 0
	self.kids      = {}
	self.poly      = {}
	self.keyframes = {}
	self.shade     = 1
end
function Bone:add_kid(k)
	table.insert(self.kids, k)
	k.parent = self
end
function Bone:delete_kid(kid)
	for i, k in ipairs(self.kids) do
		if k == kid then
			table.remove(self.kids, i)
			break
		end
	end
end
function Bone:update()
	local p = self.parent or {
		global_x   = 0,
		global_y   = 0,
		global_ang = 0,
	}
	local si = math.sin(p.global_ang)
	local co = math.cos(p.global_ang)
	self.global_x = p.global_x + self.x * co - self.y * si
	self.global_y = p.global_y + self.y * co + self.x * si
	self.global_ang = p.global_ang + self.ang
	for _, k in ipairs(self.kids) do k:update() end
end


local keyframe_buffer = {}


Model = Object:new()
function Model:init(file_name)
	if file_name then
		self:load(file_name)
	else
		self:reset()
	end
end
function Model:reset()
	self.root = Bone()
	self.root:update()
	self.bones = { self.root }
	self.anims = {}
end
function Model:add_bone(b)
	self.bones[#self.bones + 1] = b
	-- NOTE: kid bones are not added automatically
end
function Model:change_bone_layer(b, d)
	if d ~= 1 and d ~= -1 then return end
	keyframe_buffer = {}
	for i, p in ipairs(self.bones) do
		if p == b then
			if self.bones[i + d] then
				self.bones[i + d], self.bones[i] = self.bones[i], self.bones[i + d]
			end
			break
		end
	end
end
function Model:delete_bone(b)
	keyframe_buffer = {}
	for i, p in ipairs(self.bones) do
		if p == b then
			table.remove(self.bones, i)
			for _, k in ipairs(b.kids) do
				self:delete_bone(k)
			end
			break
		end
	end
end
function Model:for_all_bones(func)
	for _, b in ipairs(self.bones) do
		if func(b) then break end
	end
end
function Model:set_frame(frame)
	for _, b in ipairs(self.bones) do
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
--			l = 3 * l^2 - 2 * l^3
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
	end
	self.root:update()
end
function Model:load(name)
	self:reset()
	local file = io.open(name)
	if not file then
		return false
	end
	local str = file:read("*a")
	file:close()
	local data = loadstring("return " .. str)()
	self.anims = data.anims
	self.bones = {}
	for _, d in ipairs(data.bones) do
		local b = Bone(d.x, d.y, d.ang)
		b.poly      = d.poly or {}
		b.keyframes = d.keyframes or {}
		b.shade     = d.shade or 1
		table.insert(self.bones, b)
	end
	for i, d in ipairs(data.bones) do
		local b = self.bones[i]
		if d.parent then
			self.bones[d.parent]:add_kid(b)
		else
			self.root = b
		end
	end
	self.root:update()
	return true
end
function Model:save(name)
	local order = {}
	for i, b in ipairs(self.bones) do order[b] = i end
	local data = {
		bones = {},
		anims = self.anims,
	}
	for _, b in ipairs(self.bones) do
		local d = {
			x         = b.x,
			y         = b.y,
			ang       = b.ang,
			parent    = order[b.parent],
			shade     = b.shade,
		}
		if #b.poly > 0 then d.poly = b.poly end
		if #b.keyframes > 0 then d.keyframes = b.keyframes end
		table.insert(data.bones, d)
	end
	local file = io.open(name, "w")
	file:write(table.tostring(data) .. "\n")
	file:close()
end

-- keyframe stuff
function Model:insert_keyframe(frame)
	for _, b in ipairs(self.bones) do
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
	end
end
function Model:delete_keyframe(frame)
	for _, b in ipairs(self.bones) do
		for i, k in ipairs(b.keyframes) do
			if k[1] == frame then
				table.remove(b.keyframes, i)
				break
			end
		end
	end
end
function Model:copy_keyframe(frame)
	keyframe_buffer = {}
	for _, b in ipairs(self.bones) do
		for _, k in ipairs(b.keyframes) do
			if k[1] == frame then
				table.insert(keyframe_buffer, { k[2], k[3], k[4] })
				break
			end
		end
	end
end
function Model:paste_keyframe(frame)
	for i, b in ipairs(self.bones) do
		local q = keyframe_buffer[i]
		if not q then break end
		local kf
		for j, k in ipairs(b.keyframes) do
			if k[1] == frame then
				kf = k
				break
			end
			if k[1] > frame then
				kf = { frame }
				table.insert(b.keyframes, j, kf)
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
	end
	self:set_frame(frame)
end

