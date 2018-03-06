require("helper")
require("bone")

G = love.graphics


cam = {
	x = 0,
	y = 0,
	zoom = 1,
}


function screen_to_world(x, y)
	return	cam.x + (x - G.getWidth() / 2) * cam.zoom,
			cam.y + (y - G.getHeight() / 2) * cam.zoom
end


function love.wheelmoved(_, y)
	cam.zoom = cam.zoom * (0.9 ^ y)
end


function love.keypressed(k)
	if k == "escape" then love.event.quit() end

	local ctrl = love.keyboard.isDown("lctrl", "rctrl")

	if k == "s" and ctrl then
		save_bones("save")
		print("bones saved")
		return
	end
	if k == "l" and ctrl then
		load_bones("save")
		print("bones loaded")
		return
	end

end


function love.mousepressed(x, y, button)

	local mx, my = screen_to_world(x, y)

	if button == 2 then
		for _, b in ipairs(bones) do
			local d = math.max(
				math.abs(b.global_x - mx),
				math.abs(b.global_y - my))
			if d < 10 then
				selected_bone = b
				return
			end
		end
		selected_bone = nil
		return
	end
end


function love.mousemoved(x, y, dx, dy)
	-- move camera
	if love.mouse.isDown(3) then
		cam.x = cam.x - dx * cam.zoom
		cam.y = cam.y - dy * cam.zoom
		return
	end


	if not selected_bone then return end

	local mx, my = screen_to_world(x, y)
	dx = dx * cam.zoom
	dy = dy * cam.zoom

	-- move
	local function move(dx, dy)
		local b = selected_bone
		local si = math.sin(b.global_ang - b.ang)
		local co = math.cos(b.global_ang - b.ang)

		b.x = b.x + dx * co + dy * si
		b.y = b.y + dy * co - dx * si

		update_bone(b)
		return
	end
	if love.keyboard.isDown("g") then
		move(dx, dy)
	end

	-- rotate
	if love.keyboard.isDown("r") then
		local b = selected_bone
		local bx = mx - b.global_x
		local by = my - b.global_y
		local a = math.atan2(bx - dx, by - dy)- math.atan2(bx, by)
		if a < -math.pi then a = a + 2 * math.pi end
		if a > math.pi then a = a - 2 * math.pi end
		b.ang = b.ang + a
		update_bone(b)
		return
	end

	-- ik
	if love.mouse.isDown(1) then
		if not selected_bone.parent then
			move(dx, dy)
			return
		end

		local tx = selected_bone.global_x + dx
		local ty = selected_bone.global_y + dy

		local function calc_error()
			local dx = selected_bone.global_x - tx
			local dy = selected_bone.global_y - ty
			return (dx * dx + dy * dy) ^ 0.5
		end

		for _ = 1, 100 do
			local delta = 0.005

			local improve = false
			local b = selected_bone.parent
			while b do
				local e = calc_error()
				b.ang = b.ang + delta
				update_bone(b)
				if calc_error() > e then
					b.ang = b.ang - delta * 2
					update_bone(b)
					if calc_error() > e then
						b.ang = b.ang + delta
						update_bone(b)
					else
						improve = true
					end
				else
					improve = true
				end

				-- give parents a smaller weight
				delta = delta * 0.7

				b = b.parent
			end
			if not improve then break end
		end
		return
	end

end


tick = 0
function love.update()
	tick = tick + 1

--	root.ang = math.sin(tick * 0.02)
--	root.kids[1].ang = math.sin(tick * 0.03)
--	update_bone(root)

end


function love.draw()
	G.translate(G.getWidth() / 2, G.getHeight() / 2)
	G.scale(1 / cam.zoom)
	G.translate(-cam.x, -cam.y)
	G.setLineWidth(cam.zoom)

--	-- mouse
--	local x, y = love.mouse.getPosition()
--	local mx, my = screen_to_world(x, y)
--	G.circle("fill", mx, my, 5 * cam.zoom)


	-- axis
	do
		G.setColor(50, 50, 50)
		G.line(-1000, 0, 1000, 0)
		G.line(0, -1000, 0, 1000)

	end


	for _, b in ipairs(bones) do

		-- mesh
		G.push()
		G.translate(b.global_x, b.global_y)
		G.rotate(b.global_ang)
		G.setColor(100, 100, 255, 100)
		G.polygon("fill", b.poly)
		if b == selected_bone then
			G.setColor(100, 100, 255)
			G.polygon("line", b.poly)
		end
		G.pop()

		-- bone
		if b.parent then
			local dx = b.global_x - b.parent.global_x
			local dy = b.global_y - b.parent.global_y
			local l = (dx * dx + dy * dy) ^ 0.5 * 0.1
			G.setColor(255, 255, 255, 50)
			G.polygon("fill",
				b.parent.global_x + dy / l,
				b.parent.global_y - dx / l,
				b.parent.global_x - dy / l,
				b.parent.global_y + dx / l,
				b.global_x,
				b.global_y)
		end

		-- joint
		if b == selected_bone then
			G.setColor(255, 100, 100)
			G.circle("fill", b.global_x, b.global_y, 5 * cam.zoom)
		else
			G.setColor(255, 255, 255)
			G.circle("line", b.global_x, b.global_y, 5 * cam.zoom)
		end
	end


	G.origin()
	G.setColor(255, 255, 255)
	if selected_bone then
		local b = selected_bone
		G.print(("pos: %g, %g"):format(b.x, b.y), 10, 10)
		G.print(("ang: %g"):format(b.ang), 10, 30)
	end
end
