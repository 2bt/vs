require("world")
require("network")


local G = love.graphics

W = 320
H = 180
love.mouse.setVisible(false)
--G.setDefaultFilter("nearest", "nearest")


world:init()
client_world:init()


local name = arg[2]
local host = arg[3]

if not host then server:init() end
client:init(name, host)


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
	do
		G.setScissor()
		G.clear(30, 30, 30)
		local w = G.getWidth()
		local h = G.getHeight()
		if w / h < W / H then
			local f = w / W * H
			G.setScissor(0, (h - f) * 0.5, w, f)
			G.translate(0, (h - f) * 0.5)
			G.scale(w / W, w / W)
		else
			local f = h / H * W
			G.setScissor((w - f) * 0.5, 0, f, h)
			G.translate((w - f) * 0.5, 0)
			G.scale(h / H, h / H)
		end
	end


	G.clear(0, 0, 0)

	client_world:draw()

end
