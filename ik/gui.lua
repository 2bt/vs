PADDING = 5

gui = {
	hover_item  = nil,
	active_item = nil,
	windows = { {}, {} },
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
	local ix = win.min_x + PADDING
	local iy = win.max_y + PADDING
	win.max_y = win.max_y + h + PADDING
	win.max_x = math.max(win.max_x, win.min_x + w + PADDING)
	return { x = ix, y = iy, w = w, h = h }
end
function gui:mouse_in_box(box)
	return self.mx >= box.x and self.mx <= box.x + box.w
		and self.my >= box.y and self.my <= box.y + box.h
end


-- public functions
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

	if self.windows[2].min_x then
		self.windows[2].min_x = G.getWidth() - (self.windows[2].max_x - self.windows[2].min_x) - PADDING
	else
		self.windows[2].min_x = G.getWidth()
	end
	self.windows[2].max_x = G.getWidth() - PADDING
	self.windows[2].min_y = 0
	self.windows[2].max_y = 0

	self.current_window = self.windows[1]
end
function gui:separator()
	local win = self.current_window
	local box = self:get_new_item_box(win.max_x - win.min_x - PADDING, 4)
	G.setColor(100, 100, 100, 100)
	G.rectangle("fill", box.x - PADDING, box.y, box.w + PADDING * 2, box.h)
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

