

gui = {
	hover_item  = nil,
	active_item = nil,
	button      = nil,
}
function gui:mousemoved(x, y, dx, dy)

	return self.active_item ~= nil or self.hover_item ~= nil
end
function gui:begin()
	self.mx, self.my = love.mouse.getPosition()
	self.cx = G.getWidth() - 100 - 5
	self.cy = 5
	local b = self.pressed
	self.pressed = love.mouse.isDown(1)
	self.clicked = self.pressed and not b
	self.hover_item = nil
	if not self.pressed then
		self.active_item = nil
	end
end
function gui:mouse_in_box(box)
	return self.mx >= box.x and self.mx <= box.x + box.w
		and self.my >= box.y and self.my <= box.y + box.h
end
function gui:button(text)
	local box = {
		x = self.cx,
		y = self.cy,
		w = 100,
		h = 30,
	}
	self.cy = self.cy + 35

	local hover = self:mouse_in_box(box)
	if hover then
		self.hover_item = text
		if self.clicked then
			self.active_item = text
		end
	end

	if text == self.active_item then
		G.setColor(255, 100, 100, 100)
	elseif hover then
		G.setColor(150, 100, 100, 100)
	else
		G.setColor(100, 100, 100, 100)
	end
	G.rectangle("fill", box.x, box.y, box.w, box.h)


	G.setColor(255, 255, 255)
	G.rectangle("line", box.x, box.y, box.w, box.h)
	G.printf(text, box.x, box.y + 8, box.w, "center")

	return hover and self.clicked
end

