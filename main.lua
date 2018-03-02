local G = love.graphics
local isDown = love.keyboard.isDown

local socket = require("socket")
local port = 12347


local server = {}
function server:init()
	print("server init")
	self.udp = socket.udp()
	self.udp:settimeout(0)
	self.udp:setsockname("*", port)

	self.clients = {}
	self.tick    = 0
end
function server:update()
	if not self.udp then return end

	self.tick = self.tick + 1

	while true do
		data, ip, port = self.udp:receivefrom()
		if not data then break end

--		print(data, ip, port)

		local k = ip .. " " .. port
		if not self.clients[k] then
			print("new client joined")
			self.clients[k] = {
				ip = ip,
				port = port,

				-- game state
				tick = 0,
				x = math.random(10, 790),
				y = math.random(10, 590),
			}
		end
		local client = self.clients[k]
		client.last_receive_tick = self.tick

		-- interpret data
		client.input = data

	end

--	print("---")
	local state = ""
	for k, client in pairs(self.clients) do
		if self.tick - client.last_receive_tick > 10 then
			self.clients[k] = nil
		end
		client.tick = client.tick + 1
		--print(k, client.tick, client.input)
		local dx = tonumber(client.input:sub(1,1)) -
		           tonumber(client.input:sub(2,2))
		local dy = tonumber(client.input:sub(3,3)) -
		           tonumber(client.input:sub(4,4))
		client.x = client.x + dx * 5
		client.y = client.y + dy * 5
		state = state .. client.x .. " " .. client.y .. " "
	end

	for k, client in pairs(self.clients) do
		self.udp:sendto(state, client.ip, client.port)
	end
end


local client = {}
function client:init(host)
	print("client init")
	self.udp = socket.udp()
	self.udp:settimeout(0)
	print(self.udp:setpeername(arg[2] or "127.0.0.1", port))
end

local players = {}

function love.load()
	if arg[2] == nil then
		server:init()
--		socket.sleep(1)
	end
	client:init()
end
function love.update()
	if isDown("escape") then
		love.event.quit()
	end

	-- client sends input
	local input = ""
	for _, k in ipairs({ "right", "left", "down", "up", }) do
		input = input .. (isDown(k) and "1" or "0")
	end

	len, err = client.udp:send(input)
	if err then
		print(err)
		love.event.quit(1)
		return
	end


	-- update server
	server:update()

	-- TODO: client receives game state
	local state, err = client.udp:receive()
	if not state and err ~= "timeout" then
		print(err)
		love.event.quit()
		return
	end

	if state then
		players = {}
		for x, y in state:gmatch("([^ ]-) ([^ ]-) ") do
			table.insert(players, {
				x = tonumber(x),
				y = tonumber(y),
			})
		end
	end

end
function love.draw()
	for _, p in ipairs(players) do

		G.circle("fill", p.x, p.y, 20)
	end
end
