local PADDING = 5

gui = {
	hover_item  = nil,
	active_item = nil,
	windows = { {}, {}, {} },
}
function gui:mousemoved(x, y, dx, dy)
	for _, win in ipairs(self.windows) do
		local box = {
			x = win.min_x,
			y = win.min_y,
			w = win.max_x - win.min_x + PADDING,
			h = win.max_y - win.min_y + PADDING,
		}
		if self:mouse_in_box(box) then return true end
	end
	return self.active_item ~= nil
end
function gui:select_win(nr)
	self.current_window = self.windows[nr]
end
function gui:get_new_item_box(w, h)
	local win = self.current_window
	local box = {}
	if win.same_line then
		win.same_line = false
		box.x = win.max_cx + PADDING
		box.y = win.min_cy + PADDING
		if win.max_cy - win.min_cy - PADDING > h then
			box.y = box.y + (win.max_cy - win.min_cy - PADDING - h) / 2
		end
		win.max_cx = math.max(win.max_cx, box.x + w)
		win.max_cy = math.max(win.max_cy, box.y + h)
	else
		box.x = win.min_cx + PADDING
		box.y = win.max_cy + PADDING
		win.min_cy = win.max_cy
		win.max_cx = box.x + w
		win.max_cy = box.y + h
	end
	win.max_x = math.max(win.max_x, win.max_cx)
	win.max_y = math.max(win.max_y, win.max_cy)
	box.w = w
	box.h = h
	return box
end
function gui:mouse_in_box(box)
	return self.mx >= box.x and self.mx <= box.x + box.w
		and self.my >= box.y and self.my <= box.y + box.h
end


-- public functions
function gui:same_line()
	self.current_window.same_line = true
end
function gui:begin()

	-- input
	self.mx, self.my = love.mouse.getPosition()
	local p = self.pressed
	self.pressed = love.mouse.isDown(1)
	self.clicked = self.pressed and not p
	if not self.pressed then
		self.active_item = nil
	end
	self.hover_item = nil


	-- draw windows
	for _, w in ipairs(self.windows) do
		if w.min_x ~= w.max_x and w.min_y ~= w.max_y then
			G.setColor(50, 50, 50, 200)
			G.rectangle("fill", w.min_x, w.min_y, w.max_x - w.min_x + PADDING, w.max_y - w.min_y + PADDING,
					PADDING)
		end
	end

	-- init windows
	self.windows[1].min_x = 0
	self.windows[1].max_x = 0
	self.windows[1].min_y = 0
	self.windows[1].max_y = 0

	if not self.windows[2].min_x then
		self.windows[2].min_x = G.getWidth()
	else
		self.windows[2].min_x = G.getWidth() - (self.windows[2].max_x - self.windows[2].min_x) - PADDING
	end
	self.windows[2].max_x = G.getWidth() - PADDING
	self.windows[2].min_y = 0
	self.windows[2].max_y = 0


	if not self.windows[3].min_x then
		self.windows[3].min_y = G.getHeight()
	else
		self.windows[3].min_y = G.getHeight() - (self.windows[3].max_y - self.windows[3].min_y) - PADDING
	end
	self.windows[3].max_y = self.windows[3].min_y
	self.windows[3].min_x = 0
	self.windows[3].max_x = G.getWidth() - PADDING

	for _, w in ipairs(self.windows) do
		w.min_cx = w.min_x
		w.max_cx = w.min_x
		w.min_cy = w.min_y
		w.max_cy = w.min_y
	end

	self.current_window = self.windows[1]
end
function gui:separator()
	local win = self.current_window
	G.setColor(100, 100, 100, 100)
	if win.same_line then
		local box = self:get_new_item_box(4, win.max_cy - win.min_cy - PADDING)
		G.rectangle("fill", box.x, box.y - PADDING, box.w, box.h + PADDING * 2)
		win.same_line = true
	else
		local box = self:get_new_item_box(win.max_x - win.min_x - PADDING, 4)
		G.rectangle("fill", box.x - PADDING, box.y, box.w + PADDING * 2, box.h)
	end
end
function gui:text(fmt, ...)
	local str = fmt:format(...)
	local w = G.getFont():getWidth(str)
	local box = self:get_new_item_box(w, 14)

	G.setColor(255, 255, 255)
	G.print(str, box.x, box.y + box.h / 2 - 7)
end
function gui:radio_button(label, v, t)
	local w = G.getFont():getWidth(label)
	local box = self:get_new_item_box(20 + PADDING + w, 20)

	local hover = self:mouse_in_box(box)
	if hover then
		self.hover_item = label
		if self.clicked then
			self.active_item = label
			t[1] = v
		end
	end

	if label == self.active_item then
		G.setColor(255, 100, 100, 200)
	elseif hover then
		G.setColor(150, 100, 100, 200)
	else
		G.setColor(100, 100, 100, 200)
	end
	G.rectangle("fill", box.x, box.y, box.h, box.h, PADDING)

	if t[1] == v then
		G.setColor(255, 255, 255, 200)
		G.rectangle("fill", box.x + 5, box.y + 5, box.h - 10, box.h - 10)
	end


	G.setColor(255, 255, 255)
	G.print(label, box.x + box.h + PADDING, box.y + box.h / 2 - 7)

	return hover and self.clicked
end
function gui:button(label)
	local box = self:get_new_item_box(100, 20)

	local hover = self:mouse_in_box(box)
	if hover then
		self.hover_item = label
		if self.clicked then
			self.active_item = label
		end
	end

	if label == self.active_item then
		G.setColor(255, 100, 100, 200)
	elseif hover then
		G.setColor(150, 100, 100, 200)
	else
		G.setColor(100, 100, 100, 200)
	end
	G.rectangle("fill", box.x, box.y, box.w, box.h, PADDING)

	G.setColor(255, 255, 255)
	G.printf(label, box.x, box.y + box.h / 2 - 7, box.w, "center")

	return hover and self.clicked
end

