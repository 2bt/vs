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
					y = y * TILE_SIZE + TILE_SIZE,
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
	update_player_box(p)
end
function update_player_box(p)
	p.box = { x = p.x - 10, y = p.y - 22, w = 20, h = 22 }
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


    -- gravity
    p.vy = p.vy + GRAVITY
    local vy = clamp(p.vy, -3, 3)
    p.in_air = true



	-- horizontal movement
	p.x = p.x + p.vx
	update_player_box(p)
	local cx = self:collision(p.box, "x")
	if cx ~= 0 then
		p.x = p.x + cx
		p.vx = 0
	end

	-- vertical movement
	p.oy = p.y
	p.y = p.y + vy
	update_player_box(p)
	local cy = self:collision(p.box, "y", not fall_though and vy)
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
			if p.y + 22 > q.y and p.oy + 22 <= q.oy
			and math.abs(p.x - q.x) < 12 then
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
		if i.type == "+" then
			if i.tick > 0 and p.health < 100
			and collision(p.box, { x = i.x - 4, y = i.y - 4, w = 8, h = 8 }) ~= 0 then
				i.tick   = -1000
				p.health = math.min(p.health + 50, 100)
			end
		end
	end

	-- lava
	if World:collision(p.box, "death") == 1 then
		World:hit_player(p, 100)
		p.score = p.score - 1
	end

	-- shooting
    if input.shoot and p.shoot_delay == 0 then
        p.shoot_delay = 50
		table.insert(self.bullets, {
			player = p,
			ttl    = 30,
			x      = p.x + p.dir * 8,
			y      = p.y - 15.5,
			dir    = p.dir,
		})
    end
    if p.shoot_delay > 0 then p.shoot_delay = p.shoot_delay - 1 end

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
				local cx = collision(box, p.box, "x")
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
	while self.events[1] and self.tick - self.events[1].tick > 3 do
		table.remove(self.events, 1)
	end


	self:encode_state()
end
function World:encode_state()
	local state = {}

	-- players
	for _, p in ipairs(self.players) do
		state[#state + 1] = " " .. p.client.id
		state[#state + 1] = " " .. p.client.name
		state[#state + 1] = " " .. p.x
		state[#state + 1] = " " .. p.y
		state[#state + 1] = " " .. p.dir
		state[#state + 1] = " " .. p.health
		state[#state + 1] = " " .. p.score
	end
	state[#state + 1] = " #"

	-- bullets
	for _, b in pairs(self.bullets) do
		state[#state + 1] = " " .. b.x
		state[#state + 1] = " " .. b.y
		state[#state + 1] = " " .. b.dir
	end
	state[#state + 1] = " #"

	-- items
	state[#state + 1] = " "
	for _, i in pairs(self.items) do
		state[#state + 1] = i.tick > 0 and "1" or "0"
	end
	state[#state + 1] = "#"

	-- events
	for _, e in ipairs(self.events) do
		state[#state + 1] = " " .. e.tick
		state[#state + 1] = " " .. table.concat(e, " ") .. " #"
	end
	state[#state + 1] = " #"

	self.state = table.concat(state)
end
function World:get_player_state(client)
	return client.id .. " " .. self.state
end
