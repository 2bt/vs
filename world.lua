world = {
	players = {}
}
function world:init()

end
function world:add_player(client)
	local p = {
		client = client
	}
	table.insert(self.players, p)

	p.x = math.random(10, 790)
	p.y = math.random(10, 590)

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
	for i, p in pairs(self.players) do
		local input = p.client.input
		local dx = tonumber(input:sub(1, 1)) -
		           tonumber(input:sub(2, 2))
		local dy = tonumber(input:sub(3, 3)) -
		           tonumber(input:sub(4, 4))
		p.x = p.x + dx * 5
		p.y = p.y + dy * 5
	end
end
function world:encode_state()
	local state = ""
	for _, p in ipairs(self.players) do
		state = state .. p.x .. " " .. p.y .. " "
	end
	return state
end



local G = love.graphics
client_world = {
	players = {}
}
function client_world:decode_state(state)
	self.players = {}
	for x, y in state:gmatch("([^ ]-) ([^ ]-) ") do
		table.insert(self.players, {
			x = tonumber(x),
			y = tonumber(y),
		})
	end
end
function client_world:draw()
	for _, p in ipairs(self.players) do
		G.circle("fill", p.x, p.y, 20)
	end
end
