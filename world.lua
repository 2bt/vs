TILE_SIZE = 16

world = {}
function world:init()
	self.tick = 0
	self.players = {}
	self.tiles = {}
	for line in love.filesystem.lines("assets/map.txt") do
		self.tiles[#self.tiles + 1] = line
	end
end
function world:tile_at(x, y)
	x = x + 1
	y = y + 1
	local l = self.tiles[y]
	if not l or x < 1 or x > #l then return " " end
	return l:sub(x, x)
end
function world:add_player(client)
	local p = { client = client }
	client.player = p
	table.insert(self.players, p)

	p.x = math.random(10, W - 10)
	p.y = math.random(10, H - 10)

end
function world:remove_player(client)
	for i, p in ipairs(self.players) do
		if p.client == client then
			table.remove(self.players, i)
			return
		end
	end
end
function world:update()
	self.tick = self.tick + 1
	for i, p in pairs(self.players) do
		local input = p.client.input
		local dx = tonumber(input:sub(1, 1)) -
		           tonumber(input:sub(2, 2))
		local dy = tonumber(input:sub(3, 3)) -
		           tonumber(input:sub(4, 4))
		p.x = p.x + dx
		p.y = p.y + dy
	end

	self:encode_state()
end
function world:encode_state()
	local state = ""
	for nr, p in ipairs(self.players) do
		p.nr = nr
		state = state .. p.x .. " " .. p.y .. " "
	end
	self.state = state
end
function world:get_player_state(client)
	return client.player.nr .. " " .. self.state
end


local G = love.graphics
client_world = {}
function client_world:init()
	self.players = {}
end
function client_world:decode_state(state)
	local n = state:gmatch("([^ ]+)")

	local nr = tonumber(n())

	self.players = {}
	while true do
		local x = n()
		local y = n()
		if not x then break end
		table.insert(self.players, {
			x = tonumber(x),
			y = tonumber(y),
		})
	end

	self.player = self.players[nr]
end
function client_world:draw()
	G.setColor(150, 150, 150)
	for y = 0, 20 do
		for x = 0, 20 do
			local t = world:tile_at(x, y)
			if t == "0" then
				G.rectangle("fill", x * 16, y * 16, 16, 16)

			end
		end
	end

	for nr, p in ipairs(self.players) do
		if p == self.player then
			G.setColor(255, 100, 100)
		else
			G.setColor(100, 100, 100)
		end
		G.circle("fill", p.x, p.y, 7)
	end
end
