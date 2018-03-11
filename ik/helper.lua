Object = {}
function Object:new(o)
	o = o or {}
	setmetatable(o, self)
	local m = getmetatable(self)
	self.__index = self
	self.__call = m.__call
	self.super = m.__index and m.__index.init
	return o
end
setmetatable(Object, { __call = function(self, ...)
	local o = self:new()
	if o.init then o:init(...) end
	return o
end })


function table.tostring(t)
	local buf = {}
	local function w(o)
		local t = type(o)
		if t == "table" then
			buf[#buf+1] = "{"
			if o[1] then
				for i, a in ipairs(o) do
					if i > 1 then buf[#buf+1] = "," end
					w(a)
				end
			else
				for k, a in pairs(o) do
					buf[#buf+1] = k .. "="
					w(a)
					buf[#buf+1] = ","
				end
			end
			if buf[#buf] == "," then buf[#buf] = nil end
			buf[#buf+1] = "}"
		elseif t == "string" then
			buf[#buf+1] = ("%q"):format(o)
		elseif t == "number" then
			buf[#buf+1] = ("%g"):format(o)
		else
			buf[#buf+1] = tostring(o)
		end
	end
	w(t)
	return table.concat(buf)
end


function clamp(v, min, max)
	return math.max(min, math.min(max, v))
end
