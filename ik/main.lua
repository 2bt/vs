require("helper")
require("bone")
require("gui")

G = love.graphics


cam = {
	x = 0,
	y = 0,
	zoom = 1,
}
edit = {
	ik_length = 2,
	mode = "bone",
	poly = {},
	selected_vertices = {},
}
function edit:toggle_mode()
	self.mode = self.mode == "bone" and "mesh" or "bone"

	if self.mode == "mesh" then
		-- transform poly into world space
		local b = selected_bone
		local si = math.sin(b.global_ang)
		local co = math.cos(b.global_ang)
		self.poly = {}
		for i = 1, #b.poly, 2 do
			self.poly[i    ] = b.global_x + b.poly[i] * co - b.poly[i + 1] * si
			self.poly[i + 1] = b.global_y + b.poly[i + 1] * co + b.poly[i] * si
		end

	elseif self.mode == "bone" then

		-- transform poly back into bone space
		local b = selected_bone
		local si = math.sin(b.global_ang)
		local co = math.cos(b.global_ang)
		b.poly = {}
		for i = 1, #self.poly, 2 do
			local dx = self.poly[i    ] - b.global_x
			local dy = self.poly[i + 1] - b.global_y
			b.poly[i    ] = dx * co + dy * si
			b.poly[i + 1] = dy * co - dx * si
		end
		self.poly = {}
		self.selected_vertices = {}
	end
end
function edit:update_mouse_pos(x, y)
	self.mx = cam.x + (x - G.getWidth() / 2) * cam.zoom
	self.my = cam.y + (y - G.getHeight() / 2) * cam.zoom
end


function love.wheelmoved(_, y)
	cam.zoom = cam.zoom * (0.9 ^ y)
end


function love.keypressed(k)
	if k == "escape" then
		love.event.quit()
		return
	end

	local ctrl = love.keyboard.isDown("lctrl", "rctrl")

	if k == "s" and ctrl then
		if edit.mode == "mesh" then edit:toggle_mode() end
		save_bones("save")

	elseif k == "l" and ctrl then
		if edit.mode == "mesh" then edit:toggle_mode() end
		load_bones("save")

	elseif k == "tab" then
		edit:toggle_mode()

	elseif k == "x" and edit.mode == "bone" then
		-- delete bone
		if selected_bone.parent then
			local p = selected_bone.parent
			for i, k in ipairs(p.kids) do
				if k == selected_bone then
					table.remove(p.kids, i)
					break
				end
			end
			selected_bone = p
		end

	elseif k == "x" and edit.mode == "mesh" then
		-- delete selected vertice
		for j = #edit.selected_vertices, 1, -1 do
			local i = edit.selected_vertices[j]
			table.remove(edit.poly, i)
			table.remove(edit.poly, i)
		end
		edit.selected_vertices = {}

	end
end


function love.mousepressed(x, y, button)
	if edit.mode == "bone" and button == 2 then
		for_all_bones(function(b)
			local d = math.max(
				math.abs(b.global_x - edit.mx),
				math.abs(b.global_y - edit.my))
			if d < 10 then
				selected_bone = b
				return true
			end
		end)

	elseif edit.mode == "bone" and button == 1 and love.keyboard.isDown("c") then
		-- add new bone
		local b = selected_bone
		local si = math.sin(b.global_ang)
		local co = math.cos(b.global_ang)
		local dx = edit.mx - b.global_x
		local dy = edit.my - b.global_y
		local k = new_bone(dx * co + dy * si, dy * co - dx * si, 0)
		add_bone(b, k)
		selected_bone = k
		update_bone(k)


	elseif edit.mode == "mesh" and button == 1 and love.keyboard.isDown("c") then
		-- add new vertex
		local index = 1
		local min_l = nil
		for i = 1, #edit.poly, 2 do

			local dx1 = edit.mx - edit.poly[i]
			local dy1 = edit.my - edit.poly[i + 1]
			local dx2 = edit.mx - edit.poly[(i + 2) % #edit.poly]
			local dy2 = edit.my - edit.poly[(i + 2) % #edit.poly + 1]

			local l = dx1 * dx1 + dy1 * dy1
			dx1 = dx1 / l
			dy1 = dy1 / l
			local l = dx2 * dx2 + dy2 * dy2
			dx2 = dx2 / l
			dy2 = dy2 / l

			local l = dx1 * dy2 - dx2 * dy1
			if not min_l or l < min_l then
				min_l = l
				index = i + 2
			end
		end

		table.insert(edit.poly, index, edit.mx)
		table.insert(edit.poly, index + 1, edit.my)
		edit.selected_vertices = { index }

	elseif edit.mode == "mesh" and button == 2 then
		edit.sx = edit.mx
		edit.sy = edit.my
	end
end


function love.mousereleased(x, y, button)
	if edit.mode == "mesh" and button == 2 then

		-- select vertices

		if not love.keyboard.isDown("lshift", "rshift") then
			edit.selected_vertices = {}
		end
		if edit.mx == edit.sx and edit.my == edit.sy then
			for i = 1, #edit.poly, 2 do
				local d = math.max(
					math.abs(edit.poly[i    ] - edit.mx),
					math.abs(edit.poly[i + 1] - edit.my))
				if d < 10 then
					edit.selected_vertices[1] = i
					break
				end
			end
		else
			min_x = math.min(edit.mx, edit.sx)
			min_y = math.min(edit.my, edit.sy)
			max_x = math.max(edit.mx, edit.sx)
			max_y = math.max(edit.my, edit.sy)

			for i = 1, #edit.poly, 2 do
				local x = edit.poly[i]
				local y = edit.poly[i + 1]
				local s = x >= min_x and x <= max_x and y >= min_y and y <= max_y
				if s then
					table.insert(edit.selected_vertices, i)
				end
			end
		end

		edit.sx = nil
		edit.sy = nil
		return
	end
end


function love.mousemoved(x, y, dx, dy)
	if gui:mousemoved(x, y, dx, dy) then return end

	edit:update_mouse_pos(x, y)
	dx = dx * cam.zoom
	dy = dy * cam.zoom

	-- move camera
	if love.mouse.isDown(3) then
		cam.x = cam.x - dx
		cam.y = cam.y - dy
		return
	end


	if edit.mode == "bone" then
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
			local bx = edit.mx - b.global_x
			local by = edit.my - b.global_y
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

			for _ = 1, 200 do
				local delta = 0.0005

				local improve = false
				local b = selected_bone
				for _ = 1, edit.ik_length do
					b = b.parent
					if not b then break end

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
					delta = delta * 1.0
				end
				if not improve then break end
			end
			return
		end
	elseif edit.mode == "mesh" then

		-- move
		if love.mouse.isDown(1) then
			for _, i in ipairs(edit.selected_vertices) do
				edit.poly[i    ] = edit.poly[i    ]  + dx
				edit.poly[i + 1] = edit.poly[i + 1]  + dy
			end
		end

	end
end


tick = 0
function love.update()
	tick = tick + 1
end


function do_gui()
	G.origin()
	gui:begin()

	if gui:button("load") then
		if edit.mode == "mesh" then edit:toggle_mode() end
		load_bones("save")
	end
	if gui:button("save") then
		if edit.mode == "mesh" then edit:toggle_mode() end
		save_bones("save")
	end
	gui:separator()
	do
		local t = { edit.mode }
		gui:radio_button("bone mode", "bone", t)
		gui:radio_button("mesh mode", "mesh", t)
		if edit.mode ~= t[1] then
			edit:toggle_mode()
		end
	end

	gui:separator()
	local b = selected_bone
	gui:text("x: %g", b.x)
	gui:text("y: %g", b.y)
	gui:text("a: %.2f°", b.ang * 180 / math.pi)
end


function love.draw()
	G.translate(G.getWidth() / 2, G.getHeight() / 2)
	G.scale(1 / cam.zoom)
	G.translate(-cam.x, -cam.y)
	G.setLineWidth(cam.zoom)


	-- axis
	do
		G.setColor(50, 50, 50)
		G.line(-1000, 0, 1000, 0)
		G.line(0, -1000, 0, 1000)
	end


	for_all_bones(function(b)

		-- mesh
		G.push()
		G.translate(b.global_x, b.global_y)
		G.rotate(b.global_ang)
		if b == selected_bone then
			if edit.mode ~= "mesh" and #b.poly >= 3 then
				G.setColor(80, 150, 80, 150)
				G.polygon("fill", b.poly)
			end
		elseif #b.poly >= 3 then
			G.setColor(80, 80, 150, 150)
			G.polygon("fill", b.poly)
		end
		G.pop()

		-- bone
		if b.parent then
			local dx = b.global_x - b.parent.global_x
			local dy = b.global_y - b.parent.global_y
			local l = (dx * dx + dy * dy) ^ 0.5 * 0.1 / cam.zoom
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
		if edit.mode == "bone" then
			G.setColor(255, 255, 255)
			G.circle("fill", b.global_x, b.global_y, 5 * cam.zoom)
			if b == selected_bone then
				G.setColor(255, 255, 0, 100)
				G.circle("fill", b.global_x, b.global_y, 10 * cam.zoom)
			end
		end
	end)


	if edit.mode == "mesh" then

		-- mesh
		if #edit.poly >= 6 then
			G.setColor(80, 150, 80, 150)
			G.polygon("fill", edit.poly)
			G.setColor(255, 255, 255, 150)
			G.polygon("line", edit.poly)
		end
		G.setColor(255, 255, 255, 150)
		G.setPointSize(5)
		G.points(edit.poly)

		local s = {}
		for _, i in ipairs(edit.selected_vertices) do
			s[#s + 1] = edit.poly[i]
			s[#s + 1] = edit.poly[i + 1]
		end
		G.setColor(255, 255, 0)
		G.setPointSize(7)
		G.points(s)

		-- selection box
		if edit.sx then
			G.setColor(200, 200, 200)
			G.rectangle("line", edit.sx, edit.sy, edit.mx - edit.sx, edit.my - edit.sy)
		end
	end

	do_gui()
end
