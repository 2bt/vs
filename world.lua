TILE_SIZE = 16
GRAVITY   = 0.2

World = {}
function World:init()
	self.tick    = 0
	self.events  = {}
	self.players = {}
	self.bullets = {}
	self.items   = {}

	self.tiles   = {}
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
			elseif t == "+" then
				table.insert(self.items, {
					type = "+",
					x = x * TILE_SIZE + TILE_SIZE / 2,
					y = y * TILE_SIZE + TILE_SIZE / 2,
					tick = 0
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
			if t == "0" or t == "^"
			or t == "L"
			then
				b.x = x * TILE_SIZE
				b.y = y * TILE_SIZE
				local e = collision(box, b, axis)

				if axis == "death" then
					-- lava
					if t == "L" and e > 0 then return 1 end
				else
					if t == "0" then
						if math.abs(e) > math.abs(d) then d = e end
					elseif t == "^" then
						if axis == "y" and vel_y > 0 and e < 0 and -e <= vel_y + 0.001 then d = e end
					end
				end

			end
		end
	end

	return d
end


function World:spawn_player(p)
	local spawn = self.spawning_points[math.random(#self.spawning_points)]
	p.tick         = 0
	p.x            = spawn.x
	p.y            = spawn.y
	p.oy           = p.y
	p.vx           = 0
	p.vy           = 0
	p.in_air       = true
	p.dir          = 1
	p.old_jump     = false
	p.jump_control = true
	p.shoot_delay  = 0
	p.health       = 100
end
function World:add_player(client)
	local p = { client = client }
	client.player = p
	table.insert(self.players, p)
	self:spawn_player(p)
	p.score = 0
end
function World:remove_player(client)
	for i, p in ipairs(self.players) do
		if p.client == client then
			table.remove(self.players, i)
			return
		end
	end
end
function World:hit_player(p, value)
	p.health = math.max(p.health - value, 0)
	-- player death
	if p.health == 0 then
		p.tick = 0
		self:event({ "d", p.x, p.y })
	end
end
function World:update_player(p)
	p.tick = p.tick + 1

	local input = p.client.input

	-- respawn
	if p.health == 0 then
		if input.jump and p.tick > 60 then
			self:spawn_player(p)
		end
		return
	end

	-- turn
    if input.dx ~= 0 then p.dir = input.dx end

	-- running
	local acc = p.in_air and 0.1 or 0.5
	p.vx = clamp(input.dx * 2, p.vx - acc, p.vx + acc)

	-- jumping
	local fall_though = false
	if not p.in_air and input.jump and not p.old_jump then
		if input.dy > 0 then
			fall_though = true
		else
			p.vy           = -5.2
			p.jump_control = true
			p.in_air       = true
		end
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
        p.shoot_delay = 50
		table.insert(self.bullets, {
			player = p,
			ttl    = 30,
			x      = p.x,
			y      = p.y,
			dir    = p.dir,
		})
    end
    if p.shoot_delay > 0 then p.shoot_delay = p.shoot_delay - 1 end


    -- gravity
    p.vy = p.vy + GRAVITY
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
	p.oy = p.y
	p.y = p.y + vy
	local box = { x = p.x - 7, y = p.y - 7, w = 14, h = 14 }
	local cy = self:collision(box, "y", not fall_though and vy)
	if cy ~= 0 then
		p.y = p.y + cy
		p.vy = 0
		if cy < 0 then
			p.in_air = false
		end
	end

	-- collision with players
	for _, q in pairs(self.players) do
		if q ~= p and q.health > 0 then
			if p.y + 14 > q.y and p.oy + 14 <= q.oy
			and math.abs(p.x - q.x) < 8 then
				-- jump on other player
				p.vy = -4
				q.vy = 2
				self:hit_player(q, 50)
				if q.health == 0 then
					p.score = p.score + 1
				end
			end
		end
	end

	-- items
	for _, i in ipairs(self.items) do
		if i.tick > 0 and collision(box, { x = i.x - 4, y = i.y - 4, w = 8, h = 8 }) ~= 0 then
			i.tick   = -1000
			p.health = math.min(p.health + 50, 100)
		end
	end

	-- lava
	if World:collision(box, "death") == 1 then
		World:hit_player(p, 100)
		p.score = p.score - 1
	end

end
function World:event(e)
	e.tick = self.tick
	table.insert(self.events, e)
end
function World:update()
	self.tick = self.tick + 1

	-- players
	for _, p in pairs(self.players) do
		self:update_player(p)
	end


	-- bullets
	for i, b in pairs(self.bullets) do
		b.ttl = b.ttl - 1
		if b.ttl < 0 then
			self.bullets[i] = nil
		end

		b.x = b.x + b.dir * 7

		local box = { x = b.x - 5, y = b.y - 1, w = 10, h = 2 }
		local cx = self:collision(box, "x")
		if cx ~= 0 then
			self.bullets[i] = nil
			self:event({ "b", b.x + cx + b.dir * 7, b.y })
		end

		-- collision
		for _, p in pairs(self.players) do
			if b.player ~= p and p.health > 0 then
				local box2 = { x = p.x - 7, y = p.y - 7, w = 14, h = 14 }
				local cx = collision(box, box2, "x")
				if cx ~= 0 then
					self.bullets[i] = nil

					self:event({ "b", b.x + cx + b.dir * 6, b.y, b.dir })

					p.vx = p.vx + b.dir * 3
					p.vy = p.vy - 1.5
					self:hit_player(p, 25)
					if p.health == 0 then
						b.player.score = b.player.score + 1
					end
				end
			end
		end
	end

	-- items
	for _, i in ipairs(self.items) do
		i.tick = i.tick + 1
	end

	-- remove events
	while self.events[1] and self.tick - self.events[1].tick > 5 do
		table.remove(self.events, 1)
	end


	self:encode_state()
end
function World:encode_state()
	local state = {}

	-- players
	for nr, p in ipairs(self.players) do
		p.nr = nr
		state[#state + 1] = " " .. p.client.name .. " " .. p.x .. " " .. p.y .. " " .. p.dir .. " " .. p.health .. " " .. p.score
	end
	state[#state + 1] = " #"

	-- bullets
	for _, b in pairs(self.bullets) do
		state[#state + 1] = " " .. b.x .. " " .. b.y .. " " .. b.dir
	end
	state[#state + 1] = " #"

	-- items
	for _, i in pairs(self.items) do
		if i.tick > 0 then
			state[#state + 1] = " " .. i.type .. " " .. i.x .. " " .. i.y
		end
	end
	state[#state + 1] = " #"

	-- events
	for _, e in ipairs(self.events) do
		state[#state + 1] = " " .. e.tick .. " " .. table.concat(e, " ") .. " #"
	end
	state[#state + 1] = " #"

	self.state = table.concat(state)
end
function World:get_player_state(client)
	return client.player.nr .. " " .. self.state
end


local G = love.graphics
ClientWorld = {}
function ClientWorld:init()
	self.tick       = 0
	self.players    = {}
	self.bullets    = {}
	self.items      = {}
	self.particles  = {}
	self.event_tick = 0
end
function ClientWorld:decode_state(state)
	local n = state:gmatch("([^ ]+)")

	local nr = tonumber(n())

	self.players = {}
	self.bullets = {}
	self.items   = {}

	-- players
	while true do
		local w = n()
		if w == "#" then break end
		table.insert(self.players, {
			name   = w,
			x      = tonumber(n()),
			y      = tonumber(n()),
			dir    = tonumber(n()),
			health = tonumber(n()),
			score  = tonumber(n()),
		})
	end

	-- bullets
	while true do
		local w = n()
		if w == "#" then break end
		table.insert(self.bullets, {
			x   = tonumber(w),
			y   = tonumber(n()),
			dir = tonumber(n()),
		})
	end

	-- items
	while true do
		local w = n()
		if w == "#" then break end
		table.insert(self.items, {
			type = w,
			x    = tonumber(n()),
			y    = tonumber(n()),
		})
	end


	-- events
	local event_tick = self.event_tick
	while true do
		local w = n()
		if w == "#" then break end
		local tick = tonumber(w)
		local e = {}
		while true do
			local w = n()
			if w == "#" then break end
			e[#e + 1] = w
		end
		if tick > self.event_tick then
			self:process_event(e)
			event_tick = tick
		end
	end
	self.event_tick = event_tick

	self.player = self.players[nr]
end
function ClientWorld:process_event(e)
	if e[1] == "b" then
		-- bullet particle
		for i = 1, 4 do
			local a = math.random() * 2 * math.pi
			local s = math.random() * 4
			table.insert(self.particles, {
				type   = "b",
				ttl    = math.random(15, 35),
				x      = tonumber(e[2]),
				y      = tonumber(e[3]),
				vx     = math.sin(a) * s,
				vy     = math.cos(a) * s - 1,
				ang    = a,
				radius = 1,
			})
		end
	elseif e[1] == "d" then
		-- death particle
		for i = 1, 20 do
			local a = math.random() * 2 * math.pi
			local s = math.random() * 4 + 2
			table.insert(self.particles, {
				type   = "d",
				ttl    = math.random(40, 80),
				x      = tonumber(e[2]),
				y      = tonumber(e[3]),
				vx     = math.sin(a) * s,
				vy     = math.cos(a) * s - 2,
				ang    = a,
				radius = 4,
			})
		end
	end
end
function ClientWorld:update()
	self.tick = self.tick + 1

	for i, p in pairs(self.particles) do
		p.ttl = p.ttl - 1
		if p.ttl < 0 then
			self.particles[i] = nil
		end

		p.vx = p.vx * 0.95
		p.vy = p.vy * 0.95
		p.vy = p.vy + GRAVITY
		local vy = clamp(p.vy, -3, 3)

		local r = math.min(p.radius, p.ttl / 10)

		-- horizontal movement
		p.x = p.x + p.vx
		local box = { x = p.x - r, y = p.y - r, w = r * 2, h = r * 2 }
		local cx = World:collision(box, "x")
		if cx ~= 0 then
			p.x = p.x + cx
			p.vx = p.vx * -0.9
		end

		-- vertical movement
		p.y = p.y + vy
		local box = { x = p.x - r, y = p.y - r, w = r * 2, h = r * 2 }
		local cy = World:collision(box, "y", vy)
		if cy ~= 0 then
			p.y = p.y + cy
			p.vy = p.vy * -0.9
		end

	end
end
function ClientWorld:draw()
	G.push()
	local cam = World.spawning_points[1]
	if self.player then cam = self.player end
	G.translate(W/2 - cam.x, H/2 - cam.y)


	-- particles
	for _, p in pairs(self.particles) do
		if p.type == "b" then
			G.setColor(255, 255, 100)
		elseif p.type == "d" then
			G.setColor(255, 0, 0)
		end
		G.push()
		G.translate(p.x, p.y)
		G.rotate(p.ang)
		G.circle("fill", 0, 0, math.min(p.radius, p.ttl / 10), 5)
		G.pop()
	end


	-- bullets
	G.setColor(255, 255, 100)
	for _, b in ipairs(self.bullets) do
		G.rectangle("fill", b.x - 5, b.y - 1, 10, 2)
	end


	-- map
	do
		local x1 = math.floor((cam.x - W / 2) / TILE_SIZE)
		local x2 = math.floor((cam.x + W / 2) / TILE_SIZE)
		local y1 = math.floor((cam.y - H / 2) / TILE_SIZE)
		local y2 = math.floor((cam.y + H / 2) / TILE_SIZE)
		for y = y1, y2 do
			for x = x1, x2 do
				local t = World:tile_at(x, y)
				if t == "0" then
					G.setColor(100, 100, 100)
					G.rectangle("fill", x * 16, y * 16, 16, 16)
				elseif t == "^" then
					G.setColor(100, 100, 100)
					G.rectangle("fill", x * 16, y * 16, 16, 4)
				elseif t == "L" then
					G.setColor(180, 0, 0)
					G.rectangle("fill", x * 16, y * 16, 16, 16)
				end
			end
		end
	end

	-- items
	for _, i in ipairs(self.items) do
		if i.type == "+" then
			G.setColor(255, 255, 0)
			G.push()
			G.translate(i.x, i.y)
			G.rotate(math.sin(self.tick * 0.04) * 2)
			G.circle("line", 0, 0, 5, 6)
			G.rectangle("fill", -2.5, -0.5, 5, 1)
			G.rectangle("fill", -0.5, -2.5, 1, 5)
			G.pop()
		end
	end

	-- players
	for nr, p in ipairs(self.players) do
		if p.health > 0 then
			if p == self.player then
				G.setColor(100, 100, 255)
			else
				-- name
				G.setColor(255, 255, 255)
				G.push()
				G.translate(p.x, p.y - 22)
				G.scale(0.5)
				G.printf(p.name, -100, 0, 200, "center")
				G.pop()

				G.setColor(255, 100, 100)
			end
			G.circle("fill", p.x, p.y, 8, 6)

			-- weapon
			G.setColor(200, 200, 200)
			G.rectangle("fill", p.x - 5 + p.dir * 3, p.y  -1.5, 10, 3)

			-- health
			G.setColor(255, 255, 255, 50)
			G.rectangle("fill", p.x - 7, p.y - 13, 14, 2)
			G.setColor(0, 255, 0, 200)
			G.rectangle("fill", p.x - 7, p.y - 13, 14 * p.health / 100, 2)
		end
	end


	G.pop()


	-- score
	G.setColor(255, 255, 255)
	table.sort(self.players, function(a, b) return a.score > b.score end)
	for i, p in ipairs(self.players) do
		G.push()
		G.translate(3, 1 + 6 * (i - 1))
		G.scale(0.5)
		G.print(("%-20s"):format(p.name), 0, 0)
		G.pop()

		G.push()
		G.translate(30, 1 + 6 * (i - 1))
		G.scale(0.5)
		G.print(("%3d"):format(p.score), 0, 0)
		G.pop()
	end
end
