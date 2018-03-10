Bone = Object:new()
function Bone:init(x, y, ang)
	self.kids = {}
	self.x    = x or 0
	self.y    = y or 0
	self.ang  = ang or 0
	self.poly = {}
	self.keyframes = {}
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


Model = Object:new()
function Model:init()
	self.root = Bone()
	self.root:update()
end
function Model:for_all_bones(func)
	local function visit(b, func)
		if func(b) then return true end
		for _, k in ipairs(b.kids) do
			if visit(k, func) then return true end
		end
	end
	visit(self.root, func)
end
function Model:set_frame(frame)
	self:for_all_bones(function(b)
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
	self.root:update()
end
function Model:load(name)
	local file = io.open(name)
	local str = file:read("*a")
	file:close()
	local data = loadstring("return " .. str)()
	local function load(d)
		local b = Bone(d.x, d.y, d.ang)
		b.poly      = d.poly
		b.keyframes = d.keyframes
		for _, k in ipairs(d.kids) do
			b:add_kid(load(k))
		end
		return b
	end
	self.root = load(data)
	self.root:update()
end
function Model:save(name)
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
	local data = save(self.root)
	local file = io.open(name, "w")
	file:write(table.tostring(data) .. "\n")
	file:close()
end

-- keyframe stuff
function Model:insert_keyframe(frame)
	self:for_all_bones(function(b)
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
function Model:delete_keyframe(frame)
	self:for_all_bones(function(b)
		for i, k in ipairs(b.keyframes) do
			if k[1] == frame then
				table.remove(b.keyframes, i)
				break
			end
		end
	end)
end
local keyframe_buffer = {}
function Model:copy_keyframe(frame)
	keyframe_buffer = {}
	self:for_all_bones(function(b)
		for _, k in ipairs(b.keyframes) do
			if k[1] == frame then
				table.insert(keyframe_buffer, { k[2], k[3], k[4] })
				break
			end
		end
	end)
end
function Model:paste_keyframe(frame)
	local i = 1
	self:for_all_bones(function(b)
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
	self:set_frame(frame)
end

