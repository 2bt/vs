require("world")
require("network")


function love.load()
	world:init()
	client_world:init()

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


local G = love.graphics


W = 320
H = 180
G.setDefaultFilter("nearest", "nearest")
canvas = G.newCanvas(W, H)
love.window.setMode(W * 2, H * 2, {resizable = true})
love.mouse.setVisible(false)


function love.draw()
	G.setCanvas(canvas)
	G.clear(0, 0, 50)


	client_world:draw()


	-- draw canvas independent of resolution
	local w = G.getWidth()
	local h = G.getHeight()
	G.origin()
	if w / h < W / H then
		G.translate(0, (h - w / W * H) * 0.5)
		G.scale(w / W, w / W)
	else
		G.translate((w - h / H * W) * 0.5, 0)
		G.scale(h / H, h / H)
	end
	G.setCanvas()
	G.setColor(255, 255, 255)
	G.draw(canvas)
end
