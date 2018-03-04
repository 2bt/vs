TILE_SIZE = 16


World = {}
function World:init()
	self.tick = 0
	self.players = {}
	self.bullets = {}
	self.tiles = {}
	self.spawning_points = {}

	local y = 0
	for line in love.filesystem.lines("assets/map.txt") do
		self.tiles[#self.tiles + 1] = line

		local x = 0
		for t in line:gmatch(".") do
			if t == "@" then
				table.insert(self.spawning_points, {
					x = x * TILE_SIZE + TILE_SIZE / 2,
					y = y * TILE_SIZE + TILE_SIZE / 2,
				})
			end
			x = x + 1
		end
		y = y + 1
	end
end
function World:tile_at(x, y)
	x = x + 1
	y = y + 1
	local l = self.tiles[y]
	if not l or x < 1 or x > #l then return "0" end
	return l:sub(x, x)
end
function World:collision(box, axis, vel_y)
	vel_y = vel_y or 0

	local x1 = math.floor(box.x / TILE_SIZE)
	local x2 = math.floor((box.x + box.w) / TILE_SIZE)
	local y1 = math.floor(box.y / TILE_SIZE)
	local y2 = math.floor((box.y + box.h) / TILE_SIZE)

	local b = { w = TILE_SIZE, h = TILE_SIZE }

	local d = 0

	for x = x1, x2 do
		for y = y1, y2 do

			local t = self:tile_at(x, y)
			if t == "0" or t == "^" then

				b.x = x * TILE_SIZE
				b.y = y * TILE_SIZE

				local e = collision(box, b, axis)

				if t == "0" then
					if math.abs(e) > math.abs(d) then d = e end
				elseif t == "^" then
					if axis == "y" and vel_y > 0 and e < 0 and -e <= vel_y + 0.001 then d = e end
				end

			end
		end
	end

	return d
end


function World:add_player(client)
	local p = { client = client }
	client.player = p
	table.insert(self.players, p)

	-- spawn from random spawning point
	local spawn = self.spawning_points[math.random(#self.spawning_points)]

	p.x            = spawn.x
	p.y            = spawn.y
	p.vx           = 0
	p.vy           = 0
	p.in_air       = true
	p.dir          = 1
	p.old_jump     = false
	p.jump_control = true
	p.shoot_delay  = 0
	p.health       = 100
end
function World:remove_player(client)
	for i, p in ipairs(self.players) do
		if p.client == client then
			table.remove(self.players, i)
			return
		end
	end
end
function World:update_player(p)
	local input = p.client.input

    if input.dx ~= 0 then p.dir = input.dx end

	-- running
	local acc = p.in_air and 0.2 or 0.5
	p.vx = clamp(input.dx * 1.75, p.vx - acc, p.vx + acc)

	-- jumping
	if not p.in_air and input.jump and not p.old_jump then
        p.vy           = -5
        p.jump_control = true
        p.in_air       = true
	end
    if p.in_air then
        if p.jump_control then
            if not input.jump and p.vy < -1 then
                p.vy = -1
                p.jump_control = false
            end
            if p.vy > -1 then p.jump_control = false end
        end
    end
	p.old_jump = input.jump


	-- shooting
    if input.shoot and p.shoot_delay == 0 then
        p.shoot_delay = 10
		table.insert(self.bullets, {
			player = p,
			tick   = 0,
			x      = p.x,
			y      = p.y,
			dir    = p.dir,
		})
    end
    if p.shoot_delay > 0 then p.shoot_delay = p.shoot_delay - 1 end


    -- gravity
    p.vy = p.vy + 0.2
    local vy = clamp(p.vy, -3, 3)
    p.in_air = true



	-- horizontal movement
	p.x = p.x + p.vx
	local box = { x = p.x - 7, y = p.y - 7, w = 14, h = 14 }
	local cx = self:collision(box, "x")
	if cx ~= 0 then
		p.x = p.x + cx
		p.vx = 0
	end

	-- vertical movement
	p.y = p.y + vy
	local box = { x = p.x - 7, y = p.y - 7, w = 14, h = 14 }
	local cy = self:collision(box, "y", vy)
	if cy ~= 0 then
		p.y = p.y + cy
		p.vy = 0
		if cy < 0 then
			p.in_air = false
		end
	end
end
function World:update()
	self.tick = self.tick + 1

	-- players
	for _, p in pairs(self.players) do
		self:update_player(p)
	end


	-- bullets
	for i, b in pairs(self.bullets) do
		b.tick = b.tick + 1
		if b.tick > 25 then
			self.bullets[i] = nil
		end

		b.x = b.x + b.dir * 7

		local box = { x = b.x - 5, y = b.y - 1, w = 10, h = 2 }
		local cx = self:collision(box, "x")
		if cx ~= 0 then
			self.bullets[i] = nil
		end

		for _, p in pairs(self.players) do
			if b.player ~= p then
				local box2 = { x = p.x - 7, y = p.y - 7, w = 14, h = 14 }
				if collision(box, box2) ~= 0 then
					self.bullets[i] = nil
					p.health = math.max(p.health - 10, 0)
				end
			end
		end

	end

	self:encode_state()
end
function World:encode_state()
	local state = {}
	for nr, p in ipairs(self.players) do
		p.nr = nr
		state[#state + 1] = " " .. p.client.name .. " " .. p.x .. " " .. p.y .. " " .. p.dir .. " " .. p.health
	end

	state[#state + 1] = " #"
	for _, b in pairs(self.bullets) do
		state[#state + 1] = " " .. b.x .. " " .. b.y .. " " .. b.dir
	end

	self.state = table.concat(state)
end
function World:get_player_state(client)
	return client.player.nr .. " " .. self.state
end


local G = love.graphics
ClientWorld = {}
function ClientWorld:init()
	G.setFont(G.newFont(6))
	self.players = {}
	self.bullets = {}
end
function ClientWorld:decode_state(state)
	local n = state:gmatch("([^ ]+)")

	local nr = tonumber(n())

	self.players = {}
	self.bullets = {}

	while true do
		local w = n()
		if w == "#" then break end
		table.insert(self.players, {
			name   = w,
			x      = tonumber(n()),
			y      = tonumber(n()),
			dir    = tonumber(n()),
			health = tonumber(n()),
		})
	end

	while true do
		local w = n()
		if not w then break end
		table.insert(self.bullets, {
			x   = tonumber(w),
			y   = tonumber(n()),
			dir = tonumber(n()),
		})
	end

	self.player = self.players[nr]
end
function ClientWorld:draw()
	G.push()
	local cam = World.spawning_points[1]
	if self.player then cam = self.player end

	G.translate(W/2 - cam.x, H/2 - cam.y)


	-- draw map
	do
		local x1 = math.floor((cam.x - W / 2) / TILE_SIZE)
		local x2 = math.floor((cam.x + W / 2) / TILE_SIZE)
		local y1 = math.floor((cam.y - H / 2) / TILE_SIZE)
		local y2 = math.floor((cam.y + H / 2) / TILE_SIZE)

		G.setColor(100, 100, 100)
		for y = y1, y2 do
			for x = x1, x2 do
				local t = World:tile_at(x, y)
				if t == "0" then
					G.rectangle("fill", x * 16, y * 16, 16, 16)
				elseif t == "^" then
					G.rectangle("fill", x * 16, y * 16, 16, 4)
				end
			end
		end
	end


	G.setColor(255, 255, 100)
	for nr, b in ipairs(self.bullets) do
		if b.dir > 0 then
			G.polygon("fill",
				b.x - 7, b.y - 2,
				b.x + 7, b.y,
				b.x - 7, b.y + 2)
		else
			G.polygon("fill",
				b.x + 7, b.y - 2,
				b.x - 7, b.y,
				b.x + 7, b.y + 2)
		end
	end


	for nr, p in ipairs(self.players) do
		if p == self.player then
			G.setColor(255, 100, 100)
		else
			G.setColor(150, 150, 150)
		end
		G.circle("fill", p.x, p.y, 7)

		G.setColor(255, 255, 255)
		G.printf(p.name, p.x - 100, p.y - 23, 200, "center")

		G.setColor(255, 255, 255, 50)
		G.rectangle("fill", p.x - 7, p.y - 13, 14, 2)
		G.setColor(0, 255, 0, 200)
		G.rectangle("fill", p.x - 7, p.y - 13, 14 * p.health / 100, 2)
	end

	G.pop()
end
