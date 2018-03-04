local socket = require("socket")
local port = 12347


server = {}
function server:init()
	self.udp = socket.udp()
	self.udp:settimeout(0)
	self.udp:setsockname("*", port)

	self.clients          = {}
	self.tick             = 0
	self.clint_id_counter = 0
end
function server:update()
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
				ip   = ip,
				port = port,
				id   = self.clint_id_counter,
				tick = 0,
			}
			world:add_player(self.clients[k])
		end
		local client = self.clients[k]
		client.last_receive_tick = self.tick

		-- interpret data
		client.input = data

	end

	-- check for client timeouts
	for k, client in pairs(self.clients) do
		if self.tick - client.last_receive_tick > 30 then
			print("server:", ("client %s disconnected"):format(client.id))
			self.clients[k] = nil
			world:remove_player(client)
		end
		client.tick = client.tick + 1
	end

	-- update game state
	world:update()

	-- encode state
	local state = world:encode_state()

	-- send state to clients
	for k, client in pairs(self.clients) do
		self.udp:sendto(state, client.ip, client.port)
	end
end


client = {}
function client:init(host)
	self.udp = socket.udp()
	self.udp:settimeout(0)
	local ok, err = self.udp:setpeername(host, port)
	if not ok then
		print("error:", err)
		love.event.quit(1)
	end
end
function client:send_input()
	local isDown = love.keyboard.isDown
	local input = ""
	for _, k in ipairs({ "right", "left", "down", "up", "x" }) do
		input = input .. (isDown(k) and "1" or "0")
	end
	len, err = client.udp:send(input)
	if err then
		print("error:", err)
		love.event.quit(1)
		return
	end
end
function client:receive_state()
	local state, err = client.udp:receive()
	if not state and err ~= "timeout" then
		print("error:", err)
		love.event.quit(1)
		return
	end
	return state
end
