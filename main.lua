local name = arg[2]
local host = arg[3]
if not name then
	print("need more args:")
	print("1. player name")
	print("2. server address (optional)")
	love.event.quit()
	return
end

require("helper")
require("world")
require("network")


local G = love.graphics

W = 320
H = 180
love.mouse.setVisible(false)
G.setFont(G.newFont(10))


World:init()
ClientWorld:init()
if not host then Server:init() end
Client:init(name, host)


function love.update()
	if love.keyboard.isDown("escape") then
		love.event.quit()
	end

	-- client sends input
	Client:send_input()

	-- update server
	Server:update()

	-- receive encoded game state
	local state = Client:receive_state()

	-- decode game state
	if state then
		ClientWorld:decode_state(state)
	end

	-- update client world (particles)
	ClientWorld:update()
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

	ClientWorld:draw()

end
