require("helper")
require("model")
require("gui")

G = love.graphics
love.keyboard.setKeyRepeat(true)

model = Model()
model.anims = {
	{
		start_frame = 10,
		end_frame = 20,
		loop = true,
		speed = 0.1,
	}
}

cam = {
	x    = 0,
	y    = 0,
	zoom = 1,
}
edit = {
	is_playing        = false,
	play_speed        = 0.5,
	frame             = 0,

	show_grid         = true,
	show_bones        = true,
	show_joints       = true,

	mode              = "bone",
	ik_length         = 2,
	poly              = {},
	selected_vertices = {},
	selected_bone     = model.root,
}
function edit:set_frame(f)
	if self.mode == "mesh" then self:toggle_mode() end
	self.frame = math.max(0, f)
	model:set_frame(self.frame)

	self.current_anim = nil
	for _, a in ipairs(model.anims) do
		if self.frame >= a.start_frame
		and self.frame < a.end_frame then
			self.current_anim = a
			break
		end
	end

end
function edit:update_frame()
	if not self.is_playing then return end
	local f = self.frame + self.play_speed
	if self.current_anim then
		f = self.frame + self.current_anim.speed
		if f >= self.current_anim.end_frame then
			f = self.current_anim.start_frame + f - self.current_anim.end_frame
		end
	end
	self:set_frame(f)
end
function edit:set_playing(p)
	self.is_playing = p
	if self.is_playing then
		if self.mode == "mesh" then self:toggle_mode() end
	else
		self:set_frame(math.floor(self.frame + 0.5))
	end
end
function edit:toggle_mode()
	self.mode = self.mode == "bone" and "mesh" or "bone"

	if self.mode == "mesh" then
		self.is_playing = false
		self.frame = math.floor(self.frame + 0.5)
		model:set_frame(self.frame)

		-- transform poly into world space
		local b = self.selected_bone
		local si = math.sin(b.global_ang)
		local co = math.cos(b.global_ang)
		self.poly = {}
		for i = 1, #b.poly, 2 do
			self.poly[i    ] = b.global_x + b.poly[i] * co - b.poly[i + 1] * si
			self.poly[i + 1] = b.global_y + b.poly[i + 1] * co + b.poly[i] * si
		end

	elseif self.mode == "bone" then

		-- transform poly back into bone space
		local b = self.selected_bone
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


function love.wheelmoved(_, y)
	cam.zoom = cam.zoom * (0.9 ^ y)
end


function love.keypressed(k)
	gui:keypressed(k)

	if k == "x" and edit.mode == "bone" then
		-- delete bone
		if edit.selected_bone.parent then
			local k = edit.selected_bone
			edit.selected_bone = k.parent
			edit.selected_bone:delete_kid(k)
			model:delete_bone(k)
		end

	elseif k == "x" and edit.mode == "mesh" then
		-- delete selected vertice
		for j = #edit.selected_vertices, 1, -1 do
			local i = edit.selected_vertices[j]
			table.remove(edit.poly, i)
			table.remove(edit.poly, i)
		end
		edit.selected_vertices = {}

	elseif k == "a" and edit.mode == "mesh" then
		-- toggle select
		local v = {}
		if #edit.selected_vertices == 0 then
			for i = 1, #edit.poly, 2 do
				v[#v + 1] = i
			end
		end
		edit.selected_vertices = v
	end
end


function love.mousepressed(x, y, button)
	if edit.mode == "bone" and button == 2 then
		-- select bone
		model:for_all_bones(function(b)
			local d = math.max(
				math.abs(b.global_x - edit.mx),
				math.abs(b.global_y - edit.my)) / cam.zoom
			if d < 10 then
				edit.selected_bone = b
				return true
			end
		end)

	elseif edit.mode == "bone" and button == 1 and love.keyboard.isDown("c") then
		-- add new bone
		local b = edit.selected_bone
		local si = math.sin(b.global_ang)
		local co = math.cos(b.global_ang)
		local dx = edit.mx - b.global_x
		local dy = edit.my - b.global_y
		local k = Bone(dx * co + dy * si, dy * co - dx * si)
		model:add_bone(k)
		b:add_kid(k)
		k:update()
		edit.selected_bone = k

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
		-- vertex selection rect
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
					math.abs(edit.poly[i + 1] - edit.my)) / cam.zoom
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

	edit.mx = cam.x + (x - G.getWidth() / 2) * cam.zoom
	edit.my = cam.y + (y - G.getHeight() / 2) * cam.zoom
	dx = dx * cam.zoom
	dy = dy * cam.zoom
	if love.keyboard.isDown("lshift", "rshift") then
		dx = dx * 0.1
		dy = dy * 0.1
	end

	-- move camera
	if love.mouse.isDown(3) then
		cam.x = cam.x - dx
		cam.y = cam.y - dy
		return
	end


	if edit.mode == "bone" then
		local function move(dx, dy)
			local b = edit.selected_bone
			local si = math.sin(b.global_ang - b.ang)
			local co = math.cos(b.global_ang - b.ang)
			b.x = b.x + dx * co + dy * si
			b.y = b.y + dy * co - dx * si
			b:update()
		end


		if love.keyboard.isDown("g") then
			-- move
			move(dx, dy)

		elseif love.keyboard.isDown("r") then
			-- rotate
			local b = edit.selected_bone
			local bx = edit.mx - b.global_x
			local by = edit.my - b.global_y
			local a = math.atan2(bx - dx, by - dy) - math.atan2(bx, by)
			if a < -math.pi then a = a + 2 * math.pi end
			if a > math.pi then a = a - 2 * math.pi end
			b.ang = b.ang + a
			b:update()

		elseif love.mouse.isDown(1) then
			-- ik
			if not edit.selected_bone.parent then
				move(dx, dy)
				return
			end

			local tx = edit.selected_bone.global_x + dx
			local ty = edit.selected_bone.global_y + dy

			local function calc_error()
				local dx = edit.selected_bone.global_x - tx
				local dy = edit.selected_bone.global_y - ty
				return (dx * dx + dy * dy) ^ 0.5
			end

			for _ = 1, 200 do
				local delta = 0.0005

				local improve = false
				local b = edit.selected_bone
				for _ = 1, edit.ik_length do
					b = b.parent
					if not b then break end

					local e = calc_error()
					b.ang = b.ang + delta
					b:update()
					if calc_error() > e then
						b.ang = b.ang - delta * 2
						b:update()
						if calc_error() > e then
							b.ang = b.ang + delta
							b:update()
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

		end

	elseif edit.mode == "mesh" then

		local function get_selection_center()
			local cx = 0
			local cy = 0
			for _, i in ipairs(edit.selected_vertices) do
				cx = cx + edit.poly[i    ]
				cy = cy + edit.poly[i + 1]
			end
			cx = cx / #edit.selected_vertices
			cy = cy / #edit.selected_vertices
			return cx, cy
		end

		if love.mouse.isDown(1) then
			-- move
			for _, i in ipairs(edit.selected_vertices) do
				edit.poly[i    ] = edit.poly[i    ] + dx
				edit.poly[i + 1] = edit.poly[i + 1] + dy
			end

		elseif love.keyboard.isDown("s") then
			-- scale
			local cx, cy = get_selection_center()
			local dx1 = edit.mx - cx - dx
			local dy1 = edit.my - cy - dy
			local dx2 = edit.mx - cx
			local dy2 = edit.my - cy
			local l1 = (dx1 * dx1 + dy1 * dy1) ^ 0.5
			local l2 = (dx2 * dx2 + dy2 * dy2) ^ 0.5
			local s = l2 / l1

			for _, i in ipairs(edit.selected_vertices) do
				edit.poly[i    ] = cx + (edit.poly[i    ] - cx) * s
				edit.poly[i + 1] = cy + (edit.poly[i + 1] - cy) * s
			end

		elseif love.keyboard.isDown("r") then
			-- rotate
			local cx, cy = get_selection_center()

			local bx = edit.mx - cx
			local by = edit.my - cy
			local a = math.atan2(bx - dx, by - dy)- math.atan2(bx, by)
			if a < -math.pi then a = a + 2 * math.pi end
			if a > math.pi then a = a - 2 * math.pi end
			local si = math.sin(a)
			local co = math.cos(a)

			for _, i in ipairs(edit.selected_vertices) do
				local dx = edit.poly[i    ] - cx
				local dy = edit.poly[i + 1] - cy
				edit.poly[i    ] = cx + dx * co - dy * si
				edit.poly[i + 1] = cy + dy * co + dx * si
			end

		end
	end
end



function love.update()
	edit:update_frame()
end


function do_gui()
	G.origin()
	G.setLineWidth(1)
	gui:begin_frame()

	do
		gui:select_win(1)
		local t = { edit.mode }
		gui:radio_button("bone", "bone", t)
		gui:same_line()
		gui:radio_button("mesh", "mesh", t)
		if edit.mode ~= t[1]
		or gui.was_key_pressed["tab"] then
			edit:toggle_mode()
		end
		gui:separator()

		if gui.was_key_pressed["#"] then
			local v = not edit.show_grid
			edit.show_grid   = v
			edit.show_joints = v
			edit.show_bones  = v
		end

		gui:checkbox("grid", edit, "show_grid")
		gui:checkbox("joints", edit, "show_joints")
		gui:checkbox("bones", edit, "show_bones")
		gui:separator()

		local b = edit.selected_bone
		gui:text("x: %.2f", b.x)
		gui:text("y: %.2f", b.y)
		gui:text("a: %.2f°", b.ang * 180 / math.pi)

		if gui:button("to front") then
			model:change_bone_layer(edit.selected_bone, 1)
		end
		if gui:button("to back") then
			model:change_bone_layer(edit.selected_bone, -1)
		end

	end

	local ctrl = love.keyboard.isDown("lctrl", "rctrl")
	local shift = love.keyboard.isDown("lshift", "rshift")

	do
		gui:select_win(2)
		if gui:button("new")
		or (gui.was_key_pressed["n"] and ctrl) then
			if edit.mode == "mesh" then edit:toggle_mode() end
			model = Model()
			edit.selected_bone = model.root
		end
		gui:same_line()
		if gui:button("load")
		or (gui.was_key_pressed["l"] and ctrl) then
			if edit.mode == "mesh" then edit:toggle_mode() end
			model:load("save")
			edit.selected_bone = model.root
			print("model loaded")
		end
		gui:same_line()
		if gui:button("save")
		or (gui.was_key_pressed["s"] and ctrl) then
			if edit.mode == "mesh" then edit:toggle_mode() end
			model:save("save")
			print("model saved")
		end
		gui:same_line()
		if gui:button("quit")
		or gui.was_key_pressed["escape"] then
			love.event.quit()
		end
	end

	do
		gui:select_win(3)

		-- timeline
		local w = gui.current_window.columns[1].max_x - gui.current_window.max_cx - 5
		local box = gui:get_new_item_box(w, 45)

		-- change frame
		if gui.was_key_pressed["backspace"] then
			if edit.current_anim then
				edit:set_frame(edit.current_anim.start_frame)
			else
				edit:set_frame(0)
			end
		end
		local dx = (gui.was_key_pressed["right"] and 1 or 0)
				- (gui.was_key_pressed["left"] and 1 or 0)
		if dx ~= 0 then
			if shift then dx = dx * 10 end
			edit:set_frame(edit.frame + dx)
		end
		if gui:mouse_in_box(box) and gui.is_mouse_down then
			edit:set_frame(math.floor((gui.mx - box.x - 5) / 10 + 0.5))
		end

		G.setScissor(box.x, box.y, box.w, box.h)
		G.push()
		G.translate(box.x, box.y)

		local is_keyframe = {}
		model:for_all_bones(function(b)
			for _, k in ipairs(b.keyframes) do
				is_keyframe[k[1]] = true
			end
		end)

		G.setColor(100, 100, 100, 200)
		G.rectangle("fill", 0, 0, box.w, box.h)

		-- current frame
		G.setColor(0, 255, 0)
		local x = 5 + edit.frame * 10
		G.line(x, 0, x, 45)

		-- animations
		G.setColor(0, 255, 0, 150)
		for _, a in ipairs(model.anims) do
			local x1 = 5 + a.start_frame * 10
			local x2 = 5 + a.end_frame * 10
			G.rectangle("fill", x1, 5, x2 - x1, 10)
		end

		-- lines
		local i = 0
		for x = 5, box.w, 10 do
			G.setColor(255, 255, 255)
			if i % 10 == 0 then
				G.line(x, 35, x, 45)
				G.printf(i, x - 50, 18, 100, "center")
			else
				G.line(x, 40, x, 45)
			end

			-- keyframe
			if is_keyframe[i] then
				G.setColor(255, 200, 100)
				G.circle("fill", x, 10, 5, 4)
			end
			i = i + 1
		end

		G.pop()
		G.setScissor()

		-- play
		local t = { edit.is_playing }
		gui:radio_button("stop", false, t)
		gui:same_line()
		gui:radio_button("play", true, t)
		gui:same_line()
		if edit.is_playing ~= t[1]
		or gui.was_key_pressed["space"] then
			edit:set_playing(not edit.is_playing)
		end
		gui:separator()


		-- keyframe buttons
		gui:get_new_item_box(0, 25, 0)
		gui:same_line()
		gui:text("keyframe:")
		gui:same_line()
		if gui:button("insert") or gui.was_key_pressed["i"] then
			model:insert_keyframe(edit.frame)
		end
		gui:same_line()
		if gui:button("copy") then
			model:copy_keyframe(edit.frame)
		end
		gui:same_line()
		if gui:button("paste") then
			model:paste_keyframe(edit.frame)
		end
		gui:same_line()
		local alt = love.keyboard.isDown("lalt", "ralt")
		if gui:button("delete")
		or (gui.was_key_pressed["i"] and alt) then
			model:delete_keyframe(edit.frame)
		end
	end

	gui:end_frame()
end


local function draw_concav_poly(p)
	local tris = love.math.triangulate(p)
	for _, t in ipairs(tris) do G.polygon("fill", t) end
end
function love.draw()
	G.translate(G.getWidth() / 2, G.getHeight() / 2)
	G.scale(1 / cam.zoom)
	G.translate(-cam.x, -cam.y)
	G.setLineWidth(cam.zoom)

	-- axis and grid
	do
		G.setColor(255, 255, 255, 50)
		G.line(-1000, 0, 1000, 0)
		G.line(0, -1000, 0, 1000)
		if edit.show_grid then
			for x = -1000, 1000, 100 do
				G.line(x, -1000, x, 1000)
			end
			for y = -1000, 1000, 100 do
				G.line(-1000, y, 1000, y)
			end
		end
	end

	-- mesh
	model:for_all_bones(function(b)
		if #b.poly >= 3 then
			if b ~= edit.selected_bone or edit.mode ~= "mesh" then
				G.push()
				G.translate(b.global_x, b.global_y)
				G.rotate(b.global_ang)
				G.setColor(120, 80, 80)
				draw_concav_poly(b.poly)
				G.setColor(100, 60, 60)
				G.polygon("line", b.poly)
				G.pop()
			end
		end
	end)

	-- bone
	if edit.show_bones then
		model:for_all_bones(function(b)
			if b.parent then
				local dx = b.global_x - b.parent.global_x
				local dy = b.global_y - b.parent.global_y
				local l = (dx * dx + dy * dy) ^ 0.5 * 0.1 / cam.zoom
				G.setColor(100, 150, 200, 150)
				G.polygon("fill",
					b.parent.global_x + dy / l,
					b.parent.global_y - dx / l,
					b.parent.global_x - dy / l,
					b.parent.global_y + dx / l,
					b.global_x,
					b.global_y)
			end
		end)
	end

	-- joint
	if edit.show_joints then
		model:for_all_bones(function(b)
			if b == edit.selected_bone then
				G.setColor(255, 255, 0, 150)
				G.circle("fill", b.global_x, b.global_y, 10 * cam.zoom)
			end
			G.setColor(255, 255, 255, 150)
			G.circle("fill", b.global_x, b.global_y, 5 * cam.zoom)
		end)
	end


	if edit.mode == "mesh" then

		-- mesh
		if #edit.poly >= 6 then
			G.setColor(200, 100, 100, 150)
			draw_concav_poly(edit.poly)
			G.setColor(255, 255, 255, 150)
			G.polygon("line", edit.poly)
		end
		G.setColor(255, 255, 255, 150)
		G.setPointSize(5)
		G.points(edit.poly)

		-- selected vertices
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
