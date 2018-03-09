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
