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

Model = Object:new()
function Model:init(name)
	local str = love.filesystem.read(name)
	local data = loadstring("return " .. str)()
	self.anims = data.anims
	self.bones = {}
	for i, d in ipairs(data.bones) do
		local b = Bone(d.x, d.y, d.ang)
		b.nr        = i
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
end
function Model:make_bone_transforms()
	local bone_transforms = {}
	for _, b in ipairs(self.bones) do
		bone_transforms[b.nr] = { x = b.x, y = b.y, ang = b.ang }
	end
	return bone_transforms
end


-- weights is either:
-- + nil
-- + a weight for all bones
-- + a table of weights
function Model:update_bone_transforms(bone_transforms, frame, weights)

	weights = weights or 1
	local weight = 0
	if type(weights) == "number" then
		weight = weights
		weights = {}
	end
	local function get_weight(nr)
		return weights[nr] or weight
	end

	local function visit(b, func)
		func(b)
		for _, k in ipairs(b.kids) do
			visit(k, func)
		end
	end

	visit(self.root, function(b)

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
		local k
		if k1 and k2 then
			local l = (frame - k1[1]) / (k2[1] - k1[1])
			local function lerp(i) return k1[i] * (1 - l) + k2[i] * l end
			k = { nil, lerp(2), lerp(3), lerp(4) }
		elseif k1 or k2 then
			k = k1 or k2
		end

		local t = bone_transforms[b.nr]

		if k then
			local w = get_weight(b.nr)
			t.x   = mix(t.x,   k[2], w)
			t.y   = mix(t.y,   k[3], w)
			t.ang = mix(t.ang, k[4], w)
		end

		-- global transform
		local p = b.parent and bone_transforms[b.parent.nr] or {
			global_x   = 0,
			global_y   = 0,
			global_ang = 0,
		}
		local si = math.sin(p.global_ang)
		local co = math.cos(p.global_ang)
		t.global_x = p.global_x + t.x * co - t.y * si
		t.global_y = p.global_y + t.y * co + t.x * si
		t.global_ang = p.global_ang + t.ang
	end)
end
