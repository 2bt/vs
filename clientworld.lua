require("model")

local G = love.graphics
ClientWorld = {}
function ClientWorld:init()
	self.tick        = 0
	self.players     = {}
	self.bullets     = {}
	self.particles   = {}
	self.event_tick  = 0
	self.items       = World.items

	self.player_model = Model("assets/turri.model")
	for _, b in ipairs(self.player_model.bones) do
		if #b.poly < 3 then
			b.polys = {}
		elseif love.math.isConvex(b.poly) then
			b.polys = { b.poly }
		else
			b.polys = love.math.triangulate(b.poly)
		end
	end

	-- set up bone mask for shoot animation
	self.shoot_bone_mask = {}
	local m = self.player_model
	local a = m.anims[ANIM_SHOOT]
	for i, b in ipairs(m.bones) do

		local key
		for _, k in ipairs(b.keyframes) do
			if k[1] >= a.start and k[1] <= a.stop then
				local q = k[2] .. k[3] .. k[4]
				if not key then
					key = q
				elseif q ~= key then
					self.shoot_bone_mask[i] = 1
					break
				end
			end
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
				health     = 100,
				tick       = 0,
				hit_delay  = 0,
				anim_blend = 1,
				bone_transforms = self.player_model:make_bone_transforms(),
				spring     = 0
			}
		end
		local p = self.players[id]
		if id == player_id then
			self.player = p
		end

		local old_health = p.health
		local old_anim   = p.anim
		local old_vy     = p.vy

		p.name        = n()
		p.x           = tonumber(n())
		p.y           = tonumber(n())
		p.dir         = tonumber(n())
		p.health      = tonumber(n())
		p.score       = tonumber(n())
		p.anim        = tonumber(n())
		p.vy          = tonumber(n())
		p.shoot_delay = tonumber(n())

		if p.anim ~= old_anim then
			p.anim_tick = 0
			p.anim_blend = 0
			if old_anim == ANIM_JUMP and p.anim == ANIM_IDLE then
				p.spring = old_vy
			end
		end

		if old_health > p.health then
			p.hit_delay = 7
		end
		if old_health == 0 and p.health > 0 then
			-- player respawn
			-- TODO: particles
		end
		if old_health > 0 and p.health == 0 then
			p.tick = 0
			-- death
			for i = 1, 20 do
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
	local active_bullets = {}
	while true do
		local id = n()
		if id == "#" then break end
		id = tonumber(id)
		active_bullets[id] = true
		if not self.bullets[id] then
			self.bullets[id] = {}
		end
		local b = self.bullets[id]
		b.x   = tonumber(n())
		b.y   = tonumber(n())
		b.dir = tonumber(n())
	end
	for id, b in pairs(self.bullets) do
		if not active_bullets[id] then
			self.bullets[id] = nil
		end
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

	-- players
	for _, p in pairs(self.players) do
		p.tick = p.tick + 1
		p.anim_tick = p.anim_tick + 1

		if p.hit_delay > 0 then
			p.hit_delay = p.hit_delay - 1
		end

		-- update bones
		local frame
		if p.anim == ANIM_JUMP then
			-- jump
			local l = 0.5 + clamp(p.vy, -5, 5) / 10
			local a = self.player_model.anims[ANIM_JUMP]
			frame = mix(a.start, a.stop, l)

		elseif p.anim == ANIM_IDLE and p.spring > 0 then
			-- spring
			a = self.player_model.anims[ANIM_DUCK]
			local l = clamp(p.spring / 6, 0, 1)
			frame = mix(a.start, a.stop, l)

			p.spring = clamp(p.spring - 0.5, 0, 10)
			p.anim_tick = 0
		else
			-- running and idle
			local a = self.player_model.anims[p.anim]
			frame = a.start + (p.anim_tick * a.speed) % (a.stop - a.start)
		end

		local a = self.player_model.anims[ANIM_SHOOT]
		local shoot_frame = math.min(a.stop, a.start + (SHOOT_DELAY - p.shoot_delay) * 1.2)

		self.player_model:update_bone_transforms(p.bone_transforms, frame, p.anim_blend)
		self.player_model:update_bone_transforms(p.bone_transforms, shoot_frame, self.shoot_bone_mask)
		p.anim_blend = math.min(p.anim_blend + 0.2, 1)


		-- bleeding corpse
		if p.health == 0 and p.tick < 50 then
			local l = p.tick / 50
			for i = 1, (1 - l) * 5 do
				self:spawn_blood(p.x, p.y - 10 * (1 - l))
			end
		end
	end


	-- particles
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


function ClientWorld:draw_map(cam, layer)
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


	if layer == "bg" then

		for y = y1, y2 do
			for x = x1, x2 do
				local t = World:tile_at(x, y)
				if t == "^" then
					-- bridge
					G.setColor(100, 70, 40)
					G.polygon("fill", {
						x * 16, y * 16 - 1,
						x * 16 + 8, y * 16,
						x * 16 + 8, y * 16 + 4,
						x * 16, y * 16 + 3,
					})
					G.setColor(70, 50, 20)
					G.polygon("fill", {
						x * 16 + 8, y * 16,
						x * 16 + 16, y * 16 - 1,
						x * 16 + 16, y * 16 + 3,
						x * 16 + 8, y * 16 + 4,
					})

				elseif t == "L" then
					-- lava
					G.push()
					G.translate(x * 16, y * 16)
					G.setColor(100, 0, 0)
					G.polygon("fill", lava_poly2)
					G.pop()
				end
			end
		end


	elseif layer == "fg" then

		for y = y1, y2 do
			for x = x1, x2 do
				local t = World:tile_at(x, y)
				if t == "0" then
					-- grounding
					G.setColor(80, 50, 100)
					G.rectangle("fill", x * 16, y * 16, 16, 16)
				elseif t == "L" then
					-- lava
					G.push()
					G.translate(x * 16, y * 16)
					G.setColor(130, 0, 0)
					G.polygon("fill", lava_poly)
					G.pop()
				end
			end
		end


		-- wiggly stones
		local function X(x, y)
			return x + math.sin(x * 7777 + y * 9999) * 2
		end
		local function Y(x, y)
			return y + math.sin(x * 5555 + y * 3333) * 2
		end
		for y = y1, y2 do
			for x = x1, x2 do
				local t = World:tile_at(x, y)
				if t == "0" then
					local d = ((x * 12.341 + y * 31.421) ^ 1.2) * 41 % 30
					if d < 1 then
					elseif d < 2 then
					elseif d % 4.2 > 4 then
					else
						G.setColor(110, 80, 120)
						local x1 = x * 16
						local x2 = x * 16 + 16
						local y1 = y * 16
						local y2 = y * 16 + 16
						local poly = {
							X(x1, y1), Y(x1, y1),
							X(x2, y1), Y(x2, y1),
							X(x2, y2), Y(x2, y2),
							X(x1, y2), Y(x1, y2),
						}
						G.polygon("fill", poly)
					end
				end
			end
		end

		-- special stones
		for y = y1, y2 do
			for x = x1, x2 do
				local t = World:tile_at(x, y)
				if t == "0" then
					local d = ((x * 12.341 + y * 31.421) ^ 1.2) * 41 % 30
					if d < 1 then

						G.setColor(100, 70, 110)
						G.rectangle("fill", x * 16, y * 16, 16, 16, r)
						G.setColor(60, 80, 90)
						G.rectangle("fill", x * 16 + 2, y * 16 + 3, 7, 6)

					elseif d < 2 then
						-- screws
						G.setColor(100, 80, 100)
						G.rectangle("fill", x * 16, y * 16, 16, 16)
						G.setColor(60, 60, 80)
						G.rectangle("fill", x * 16 + 1, y * 16 + 1, 2, 2)
						G.rectangle("fill", x * 16 + 1, y * 16 + 13, 2, 2)
						G.rectangle("fill", x * 16 + 13, y * 16 + 1, 2, 2)
						G.rectangle("fill", x * 16 + 13, y * 16 + 13, 2, 2)

					elseif d % 4.2 > 4 then
						-- rounded box
						G.setColor(110, 100, 120)
						G.rectangle("fill", x * 16, y * 16, 16, 16, 3)
					end

				end
			end
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


	-- map
	self:draw_map(cam, "bg")


	-- particles
	for _, p in pairs(self.particles) do
		if p.type == "b" then
			G.setColor(255, 255, 100)
		elseif p.type == "d" then
			G.setColor(255 * p.shade, 0, 0)
		end
--		G.circle("fill", p.x, p.y, math.min(p.radius, p.ttl / 10))
		G.push()
		G.translate(p.x, p.y)
		G.rotate(math.atan2(p.vy, p.vx))
		G.scale(1 + ((p.vx * p.vx + p.vy * p.vy) ^ 0.5) * 0.5, 1)
		G.circle("fill", 0, 0, math.min(p.radius, p.ttl / 10))
		G.pop()
	end


	-- items
	for _, item in ipairs(self.items) do
		if item.state and item.type == "+" then
			G.push()
			G.translate(item.x, item.y)
			G.rotate(math.sin(self.tick * 0.02) * 1.4)
			G.setColor(180, 180, 180)
			G.circle("fill", 0, 0, 5, 6)
			G.rotate(math.sin(self.tick * 0.02 + 0.8))
			G.setColor(200, 0, 0)
			G.rectangle("fill", -2.5, -1, 5, 2)
			G.rectangle("fill", -1, -2.5, 2, 5)
			G.pop()
		end
	end


	-- bullets
	for _, b in pairs(self.bullets) do
		G.setColor(255, 255, 100)
		G.rectangle("fill", b.x - 5, b.y - 1.5, 10, 3, 1)
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
			if p.hit_delay > 0 then
				color = { 255, 255, 255 }
			end


			-- render bones
			G.push()
			G.translate(p.x, p.y)
			G.scale(0.08)
			G.scale(p.dir, 1)
			for i, b in ipairs(self.player_model.bones) do
				if #b.polys > 0 then
					-- the gun gets a special color
					if b.shade == 0.5 then
						G.setColor(60, 50, 40)
					else
						G.setColor(color[1] * b.shade, color[2] * b.shade, color[3] * b.shade)
					end
					local t = p.bone_transforms[i]
					G.push()
					G.translate(t.global_x, t.global_y)
					G.rotate(t.global_ang)
					for _, p in ipairs(b.polys) do
						G.polygon("fill", p)
					end
					G.pop()
				end
			end
			G.pop()

		end
	end


	-- muzzle flash
	for _, p in pairs(self.players) do
		if p.health > 0 and p.shoot_delay >= SHOOT_DELAY - 1 then
			G.setColor(255, 255, 255)
			G.circle("fill", p.x + p.dir * 12, p.y - 15.5, 6)
		end
	end

	self:draw_map(cam, "fg")

	-- health
	for _, p in pairs(self.players) do
		if p.health > 0 then
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
