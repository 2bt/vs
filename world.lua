function collision(a, b, axis)
	if a.x >= b.x + b.w
	or a.y >= b.y + b.h
	or a.x + a.w <= b.x
	or a.y + a.h <= b.y then return 0 end

	local dx = b.x + b.w - a.x
	local dy = b.y + b.h - a.y

	local dx2 = b.x - a.x - a.w
	local dy2 = b.y - a.y - a.h

	if axis == "x" then
		return math.abs(dx) < math.abs(dx2) and dx or dx2
	else
		return math.abs(dy) < math.abs(dy2) and dy or dy2
	end
end
function clamp(v, min, max)
	return math.max(min, math.min(max, v))
end

TILE_SIZE = 16


world = {}
function world:init()
	self.tick = 0
	self.players = {}
	self.tiles = {}
	self.spawns = {}

	local y = 0
	for line in love.filesystem.lines("assets/map.txt") do
		self.tiles[#self.tiles + 1] = line

		local x = 0
		for t in line:gmatch(".") do
			if t == "@" then
				table.insert(self.spawns, {
					x = x * TILE_SIZE + TILE_SIZE / 2,
					y = y * TILE_SIZE + TILE_SIZE / 2,
				})
			end
			x = x + 1
		end
		y = y + 1
	end
end
function world:tile_at(x, y)
	x = x + 1
	y = y + 1
	local l = self.tiles[y]
	if not l or x < 1 or x > #l then return "0" end
	return l:sub(x, x)
end
function world:collision(box, axis, vel_y)
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


function world:add_player(client)
	local p = { client = client }
	client.player = p
	table.insert(self.players, p)

	local spawn = self.spawns[math.random(#self.spawns)]
	p.x = spawn.x
	p.y = spawn.y
	p.vx = 0
	p.vy = 0
	p.in_air = true
	p.dir = 1
	p.old_jump = false
	p.jump_control = true
end
function world:remove_player(client)
	for i, p in ipairs(self.players) do
		if p.client == client then
			table.remove(self.players, i)
			return
		end
	end
end
function world:update_player(p)
	local input = p.client.input
	local dx = tonumber(input:sub(1, 1)) -
			   tonumber(input:sub(2, 2))
	local dy = tonumber(input:sub(3, 3)) -
			   tonumber(input:sub(4, 4))
	local jump = input:sub(5, 5) == "1"


    if dx ~= 0 then p.dir = dx end

	-- running
    p.vx = clamp(dx * 1.5, p.vx - 0.25, p.vx + 0.25)

	-- jumping
	if not p.in_air and jump and not p.old_jump then
        p.vy           = -5
        p.jump_control = true
        p.in_air       = true
	end
    if p.in_air then
        if p.jump_control then
            if not jump and p.vy < -1 then
                p.vy = -1
                p.jump_control = false
            end
            if p.vy > -1 then p.jump_control = false end
        end
    end

    -- gravity
    p.vy = p.vy + 0.2
    local vy = clamp(p.vy, -3, 3)

    p.in_air = true




	-- horizontal movement
	p.x = p.x + p.vx

	local b = { x = p.x - 7, y = p.y - 7, w = 14, h = 14 }
	local cx = self:collision(b, "x")
	if cx ~= 0 then
		p.x = p.x + cx
		p.vx = 0
	end

	-- vertical movement
	p.y = p.y + vy

	local b = { x = p.x - 7, y = p.y - 7, w = 14, h = 14 }
	local cy = self:collision(b, "y", vy)
	if cy ~= 0 then
		p.y = p.y + cy
		p.vy = 0
		if cy < 0 then
			p.in_air = false
		end
	end


	--
	p.old_jump = jump
end
function world:update()
	self.tick = self.tick + 1
	for i, p in pairs(self.players) do
		self:update_player(p)
	end

	self:encode_state()
end
function world:encode_state()
	local state = ""
	for nr, p in ipairs(self.players) do
		p.nr = nr
		state = state .. " " .. p.x .. " " .. p.y .. " " .. p.dir
	end
	self.state = state
end
function world:get_player_state(client)
	return client.player.nr .. " " .. self.state
end


local G = love.graphics
client_world = {}
function client_world:init()
	self.players = {}
end
function client_world:decode_state(state)
	local n = state:gmatch("([^ ]+)")

	local nr = tonumber(n())

	self.players = {}
	while true do
		local x = n()
		if not x then break end
		table.insert(self.players, {
			x = tonumber(x),
			y = tonumber(n()),
			dir = tonumber(n()),
		})
	end

	self.player = self.players[nr]
end
function client_world:draw()
	G.push()
	local cam = world.spawns[1]
	if self.player then cam = self.player end

	G.translate(W/2 - cam.x, H/2 - cam.y)


	-- draw map
	do
		local x1 = math.floor((cam.x - W / 2) / TILE_SIZE)
		local x2 = math.floor((cam.x + W / 2) / TILE_SIZE)
		local y1 = math.floor((cam.y - H / 2) / TILE_SIZE)
		local y2 = math.floor((cam.y + H / 2) / TILE_SIZE)

		G.setColor(150, 150, 150)
		for y = y1, y2 do
			for x = x1, x2 do
				local t = world:tile_at(x, y)
				if t == "0" then
					G.rectangle("fill", x * 16, y * 16, 16, 16)
				elseif t == "^" then
					G.rectangle("fill", x * 16, y * 16, 16, 4)
				end
			end
		end
	end



	G.setColor(100, 100, 100)
	for nr, p in ipairs(self.players) do
		if p ~= self.player then
			G.circle("fill", p.x, p.y, 7)
		end
	end
	if self.player then
		local p = self.player
		G.setColor(255, 100, 100)
		G.circle("fill", p.x, p.y, 7)
	end

	G.pop()
end
