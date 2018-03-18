require("ik/model")

local G = love.graphics
ClientWorld = {}
function ClientWorld:init()
	self.tick        = 0
	self.players     = {}
	self.bullets     = {}
	self.particles   = {}
	self.event_tick  = 0
	self.items       = World.items

	self.player_model = Model("ik/turri")
	for _, b in ipairs(self.player_model.bones) do
		if #b.poly < 3 then
			b.polys = {}
		elseif love.math.isConvex(b.poly) then
			b.polys = { b.poly }
		else
			b.polys = love.math.triangulate(b.poly)
		end
	end
end
function ClientWorld:spawn_blood(x, y)
	local a = math.random() * 2 * math.pi
	local s = math.random() * 3 + 1
	local b = math.random() * 2 * math.pi
	local t = math.random() * 15
	table.insert(self.particles, {
		type   = "d",
		ttl    = math.random(40, 80),
		x      = x + math.sin(b) * t,
		y      = y + math.cos(b) * t,
		vx     = math.sin(a) * s,
		vy     = math.cos(a) * s - 1,
		radius = 1 + math.random() * 3,
		bounce = 0.2 + math.random() * 0.4,
		fric   = 0.4 + math.random() * 0.4,
		shade  = 0.6 + math.random() * 0.4,
	})
end
function ClientWorld:decode_state(state)

	local n = state:gmatch("([^ ]+)")
	local player_id = tonumber(n())

	-- players
	local active_players = {}
	while true do
		local id = n()
		if id == "#" then break end
		id = tonumber(id)
		active_players[id] = true
		if not self.players[id] then
			self.players[id] = {
				health = 100,
				tick   = 0,
			}
		end
		local p = self.players[id]
		if id == player_id then
			self.player = p
		end

		p.old_health = p.health

		p.name   = n()
		p.x      = tonumber(n())
		p.y      = tonumber(n())
		p.dir    = tonumber(n())
		p.health = tonumber(n())
		p.score  = tonumber(n())

		if p.old_health == 0 and p.health > 0 then
			-- TODO: particles
		end
		if p.old_health > 0 and p.health == 0 then
			p.tick = 0
			-- death
			for i = 1, 40 do
				self:spawn_blood(p.x, p.y - 10)
			end

		end
	end
	for id, p in pairs(self.players) do
		if not active_players[id] then
			self.players[id] = nil
			print(("client: player %s disconnected"):format(p.name))
			-- TODO: particles
		end
	end


	-- bullets
	self.bullets = {}
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
	local item_states = n()
	for i, item in ipairs(self.items) do
		local s = item.state
		item.state = item_states:sub(i, i) == "1"
		if s and item.state ~= s then
			-- TODO: particles
		end
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
end
function ClientWorld:process_event(e)
	if e[1] == "b" then
		-- bullet particle
		for i = 1, 7 do
			local a = math.random() * 2 * math.pi
			local s = 1 + math.random() * 2
			table.insert(self.particles, {
				type   = "b",
				ttl    = math.random(15, 35),
				x      = tonumber(e[2]),
				y      = tonumber(e[3]),
				vx     = math.sin(a) * s,
				vy     = math.cos(a) * s - 1,
				radius = 0.5 + math.random(),
				bounce = 0.3 + math.random() * 0.5,
			})
		end
	end
end
function ClientWorld:update()
	self.tick = self.tick + 1

	for _, p in pairs(self.players) do
		p.tick = p.tick + 1

		-- bleeding corpse
		if p.health == 0 and p.tick < 50 then
			for i = 1, 5 - p.tick / 10 do
				self:spawn_blood(p.x, p.y - 10)
			end
		end
	end

	for i, p in pairs(self.particles) do
		p.ttl = p.ttl - 1
		if p.ttl < 0 then
			self.particles[i] = nil
		end

		p.vx = p.vx * 0.97
		p.vy = p.vy * 0.97

		p.vy = p.vy + GRAVITY
		local vy = clamp(p.vy, -3, 3)

		p.radius = p.radius * 0.99

		local r = math.min(p.radius, p.ttl / 10)

		-- horizontal movement
		p.x = p.x + p.vx
		local box = { x = p.x - r, y = p.y - r, w = r * 2, h = r * 2 }
		local cx = World:collision(box, "x")
		if cx ~= 0 then
			p.x = p.x + cx
			p.vx = p.vx * -p.bounce
			p.vy = p.vy * (p.fric or 1)
		end

		-- vertical movement
		p.y = p.y + vy
		local box = { x = p.x - r, y = p.y - r, w = r * 2, h = r * 2 }
		local cy = World:collision(box, "y", vy)
		if cy ~= 0 then
			p.y = p.y + cy
			p.vy = p.vy * -p.bounce
			p.vx = p.vx * (p.fric or 1)
		end

	end
end
function ClientWorld:draw()
	G.push()
	local cam = World.spawning_points[1]
	if self.player then
		cam = {
			x = self.player.x,
			y = self.player.y - 10,
		}
	end
	G.translate(W/2 - cam.x, H/2 - cam.y)


	-- particles
	for _, p in pairs(self.particles) do
		if p.type == "b" then
			G.setColor(255, 255, 100)
		elseif p.type == "d" then
			G.setColor(255 * p.shade, 0, 0)
		end
		G.circle("fill", p.x, p.y, math.min(p.radius * 1.1, p.ttl / 10))
	end


	-- map
	do
		local lava_poly = { TILE_SIZE, TILE_SIZE, 0, TILE_SIZE }
		local lava_poly2 = { TILE_SIZE, TILE_SIZE, 0, TILE_SIZE }
		for i = 0, TILE_SIZE, TILE_SIZE / 4 do
			lava_poly[#lava_poly + 1] = i
			lava_poly[#lava_poly + 1] = math.sin(i / TILE_SIZE * 2 * math.pi + self.tick * 0.1) * 2
		end
		for i = 0, TILE_SIZE, TILE_SIZE / 3 do
			lava_poly2[#lava_poly2 + 1] = i
			lava_poly2[#lava_poly2 + 1] = math.sin(i / TILE_SIZE * 2 * math.pi - self.tick * 0.07) * 2
		end

		local x1 = math.floor((cam.x - W / 2) / TILE_SIZE)
		local x2 = math.floor((cam.x + W / 2) / TILE_SIZE)
		local y1 = math.floor((cam.y - H / 2) / TILE_SIZE)
		local y2 = math.floor((cam.y + H / 2) / TILE_SIZE)
		for y = y1, y2 do
			for x = x1, x2 do
				local t = World:tile_at(x, y)
				if t == "0" then
					local d = ((x * 12.341 + y * 31.421) ^ 1.2) * 41 % 30
					if d < 1 then
						G.setColor(110, 80, 120)
						G.rectangle("fill", x * 16, y * 16, 16, 16, r)
						G.setColor(60, 80, 90)
						G.rectangle("fill", x * 16 + 2, y * 16 + 3, 7, 6)
					elseif d < 2 then
						G.setColor(100, 80, 100)
						G.rectangle("fill", x * 16, y * 16, 16, 16)
						G.setColor(60, 60, 80)
						G.rectangle("fill", x * 16 + 1, y * 16 + 1, 2, 2)
						G.rectangle("fill", x * 16 + 1, y * 16 + 13, 2, 2)
						G.rectangle("fill", x * 16 + 13, y * 16 + 1, 2, 2)
						G.rectangle("fill", x * 16 + 13, y * 16 + 13, 2, 2)
					elseif d % 4.2 > 4 then
						G.setColor(110, 100, 120)
						G.rectangle("fill", x * 16, y * 16, 16, 16, 3)
					else
						G.setColor(110, 80, 120)
						G.rectangle("fill", x * 16, y * 16, 16, 16)
					end
				elseif t == "^" then
					G.setColor(50, 30, 0)
					G.rectangle("fill", x * 16, y * 16, 16, 4)
					G.setColor(130, 80, 50)
					G.rectangle("line", x * 16 + 0.5, y * 16 + 0.5, 7, 3)
					G.rectangle("line", x * 16 + 0.5 + 8, y * 16 + 0.5, 7, 3)
				elseif t == "L" then
					G.push()
					G.translate(x * 16, y * 16)
					G.setColor(100, 0, 0)
					G.polygon("fill", lava_poly2)
					G.setColor(130, 0, 0)
					G.polygon("fill", lava_poly)
					G.pop()
				end
			end
		end
	end

	-- items
	for _, item in ipairs(self.items) do
		if item.state and item.type == "+" then
			G.setColor(255, 255, 0)
			G.push()
			G.translate(item.x, item.y)
			G.rotate(math.sin(self.tick * 0.04) * 2)
			G.circle("line", 0, 0, 5, 6)
			G.rectangle("fill", -2.5, -0.5, 5, 1)
			G.rectangle("fill", -0.5, -2.5, 1, 5)
			G.pop()
		end
	end


	-- bullets
	G.setColor(255, 255, 100)
	for _, b in ipairs(self.bullets) do
		G.rectangle("fill", b.x - 5, b.y - 1, 10, 2)
	end



	-- players
	for _, p in pairs(self.players) do
		if p.health > 0 then

			local color = { 100, 100, 255 }
			if p ~= self.player then
				color = { 255, 100, 100 }

				-- name
				G.setColor(255, 255, 255)
				G.push()
				G.translate(p.x, p.y - 37)
				G.scale(0.4)
				G.printf(p.name, -100, 0, 200, "center")
				G.pop()
			end

			-- player got hit
			if p.old_health > p.health then
				color = { 255, 255, 255 }
			end

			local m = self.player_model
			local a = m.anims[1]
			local f = a.start + (self.tick * 0.5) % (a.stop - a.start)
			m:set_frame(f)
			G.push()
			G.translate(p.x, p.y)
			G.scale(0.08)
			G.scale(p.dir, 1)

			for i, b in ipairs(m.bones) do
				if #b.polys > 0 then
					G.setColor(color[1] * b.shade, color[2] * b.shade, color[3] * b.shade)
					G.push()
					G.translate(b.global_x, b.global_y)
					G.rotate(b.global_ang)
					for _, p in ipairs(b.polys) do
						G.polygon("fill", p)
					end
					G.pop()
				end
			end
			G.pop()

			-- health
			G.setColor(255, 255, 255, 50)
			G.rectangle("fill", p.x - 7, p.y - 28, 14, 2)
			G.setColor(0, 255, 0, 200)
			G.rectangle("fill", p.x - 7, p.y - 28, 14 * p.health / 100, 2)
		end
	end


	G.pop()


	-- score
	G.setColor(255, 255, 255)
	local ps = {}
	for _, p in pairs(self.players) do
		ps[#ps + 1] = p
	end
	table.sort(ps, function(a, b) return a.score > b.score end)
	for i, p in ipairs(ps) do
		G.push()
		G.translate(3, 1 + 6 * (i - 1))
		G.scale(0.4)
		G.print(("%-20s"):format(p.name), 0, 0)
		G.pop()

		G.push()
		G.translate(30, 1 + 6 * (i - 1))
		G.scale(0.4)
		G.print(("%3d"):format(p.score), 0, 0)
		G.pop()
	end
end

