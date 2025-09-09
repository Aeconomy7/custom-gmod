util.PrecacheModel("materials/bl_mats/smiley.vtf")

local function GetMoveVector(mv)
	local ang = mv:GetAngles()

	local max_speed = mv:GetMaxSpeed()

	local forward = math.Clamp(mv:GetForwardSpeed(), -max_speed, max_speed)
	local side = math.Clamp(mv:GetSideSpeed(), -max_speed, max_speed)

	local abs_xy_move = math.abs(forward) + math.abs(side)

	if abs_xy_move == 0 then
		return Vector(0, 0, 0)
	end

	local mul = max_speed / abs_xy_move

	local vec = Vector()

	vec:Add(ang:Forward() * forward)
	vec:Add(ang:Right() * side)

	vec:Mul(mul)

	return vec
end

hook.Add("SetupMove", "Multi Jump", function(ply, mv)
	-- Let the engine handle movement from the ground
	if ply:OnGround() then
		ply:SetJumpLevel(0)

		return
	end	

	-- Don't do anything if not jumping
	if not mv:KeyPressed(IN_JUMP) then
		return
	end

	ply:SetJumpLevel(ply:GetJumpLevel() + 1)

	if ply:GetJumpLevel() > ply:GetMaxJumpLevel() then
		return
	end

	local vel = GetMoveVector(mv)

	vel.z = ply:GetJumpPower() * ply:GetExtraJumpPower()

	mv:SetVelocity(vel)

	ply:DoCustomAnimEvent(PLAYERANIMEVENT_JUMP , -1)

	if SERVER then
		ply:EmitSound("bl_sounds/jump.wav", 30, 100, 1, CHAN_AUTO)
		-- local sprite = ents.Create("env_sprite")
		-- if IsValid(sprite) then
		-- 	sprite:SetKeyValue("model", "materials/bl_mats/smiley.vtf")
		-- 	sprite:SetKeyValue("rendermode", "3")
		-- 	-- sprite:SetKeyValue("scale", "0.5") -- Small size
		-- 	-- Random color hue
		-- 	local hue = math.random(0, 360)
		-- 	local r, g, b = HSVToColor(hue, 1, 1).r, HSVToColor(hue, 1, 1).g, HSVToColor(hue, 1, 1).b
		-- 	sprite:SetKeyValue("color", string.format("%d %d %d", r, g, b))
		-- 	sprite:SetPos(ply:GetPos() + Vector(0,0,10))
		-- 	sprite:Spawn()
		-- 	sprite:Fire("Kill", "", 1) -- Remove after 1 second
		-- end
	end
end)