local socket = require("socket")


local PORT = 12347


Server = {}
function Server:init()
	self.udp = socket.udp()
	self.udp:settimeout(0)
	self.udp:setsockname("*", PORT)

	self.clients          = {}
	self.tick             = 0
	self.clint_id_counter = 0
end
function Server:update()
	if not self.udp then return end

	self.tick = self.tick + 1

	-- receive input
	while true do
		data, ip, port = self.udp:receivefrom()
		if not data then break end

		local k = ip .. " " .. port
		if not self.clients[k] then
			self.clint_id_counter = self.clint_id_counter + 1
			print("server:", ("client %s joined"):format(self.clint_id_counter))
			self.clients[k] = {
				ip    = ip,
				port  = port,
				id    = self.clint_id_counter,
				tick  = 0,
				name  = data:sub(7):gsub(" ", "_"),
			}
			World:add_player(self.clients[k])
		end
		local client = self.clients[k]
		client.last_receive_tick = self.tick

--		if client.id == 2 then
--			data = "1000" .. (self.tick % 40 < 30 and 1 or 0) .."0foobar"
--		end
		-- interpret data
		client.input = {
			dx = tonumber(data:sub(1, 1)) - tonumber(data:sub(2, 2)),
			dy = tonumber(data:sub(3, 3)) - tonumber(data:sub(4, 4)),
			jump = data:sub(5, 5) == "1",
			shoot = data:sub(6, 6) == "1",
		}

	end

	-- check for client timeouts
	for k, client in pairs(self.clients) do
		if self.tick - client.last_receive_tick > 30 then
			print("server:", ("client %s disconnected"):format(client.id))
			self.clients[k] = nil
			World:remove_player(client)
		end
		client.tick = client.tick + 1
	end

	-- update game state
	World:update()

	-- send state to clients
	for k, client in pairs(self.clients) do
		self.udp:sendto(World:get_player_state(client), client.ip, client.port)
	end
end


Client = {}
function Client:init(name, host)
	self.udp = socket.udp()
	self.udp:settimeout(0)
	self.name = name or "unknown"
	local ok, err = self.udp:setpeername(host or "localhost", PORT)
	if not ok then
		print("error:", err)
		love.event.quit(1)
	end
end
function Client:send_input()
	local isDown = love.keyboard.isDown
	local input = ""
	for _, k in ipairs({ "right", "left", "down", "up", "x", "c" }) do
		input = input .. (isDown(k) and "1" or "0")
	end
	len, err = self.udp:send(input .. self.name)
	if err then
		print("error:", err)
		love.event.quit(1)
		return
	end
end
function Client:receive_state()
	local state, err = self.udp:receive()
	if not state and err ~= "timeout" then
		print("error:", err)
		love.event.quit(1)
		return
	end
	return state
end
