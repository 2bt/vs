require("world")
require("network")


function love.load()
	world:init()
	if arg[2] == nil then server:init() end
	client:init(arg[2] or "127.0.0.1")
end


function love.update()
	if love.keyboard.isDown("escape") then
		love.event.quit()
	end

	-- client sends input
	client:send_input()

	-- update server
	server:update()

	-- receive encoded game state
	local state = client.receive_state()

	-- decode game state
	if state then
		client_world:decode_state(state)
	end

end
function love.draw()
	client_world:draw()
end
