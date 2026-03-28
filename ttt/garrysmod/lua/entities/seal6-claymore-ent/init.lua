ENT.WeaponClass = "seal6-claymore"
ENT.ClaymoreModel = "models/hoff/weapons/claymore/w_claymore.mdl"

ENT.Exploded = false
ENT.Setup = false
ENT.TriggeredByOwner = false
-------------------------------
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )
-------------------------------

--------------------
-- Spawn Function --
--------------------
function ENT:SpawnFunction( ply, tr )

	if ( !tr.Hit ) then return end
	local SpawnPos = tr.HitPos + tr.HitNormal * 25
	local ent = ents.Create( "seal6-claymore-ent" )
	ent:SetPos( SpawnPos )
	ent:Spawn()
	ent:Activate()
	ent:GetOwner(self.ClayOwner)
	ent:SetCollisionSound("")
	return ent

end

----------------
-- Initialize --
----------------
function ENT:Initialize()

	self:SetModel( self.ClaymoreModel )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
	self:SetFriction(0)

	self.TriggeredByOwner = GetConVar("Claymore_OwnerTrigger") and GetConVar("Claymore_OwnerTrigger"):GetBool() or false

	local phys = self:GetPhysicsObject()
	if (phys:IsValid()) then
		phys:Wake()
	end

	self.Spawned = CurTime()
	local tr = self:Trace()
	if ( tr.Hit and tr.Entity and tr.Entity:IsValid() and !tr.Entity:IsPlayer() ) then
		self.InitEnt = tr.Entity
	end
end

function ENT:Think()

	local pos = self:GetPos() + self:GetRight() * -30
	--local ang = self:GetAngles() + Angle(0,-90,0)
	local tracedata = {}
	tracedata.ignoreworld = true
	tracedata.collisiongroup = COLLISION_GROUP_PLAYER
	tracedata.start = pos
	tracedata.endpos = pos -- extend the endpos far enough to cover all three traces
	if !self.TriggeredByOwner then
		tracedata.filter = {self, self.ClayOwner}
	else
		tracedata.filter = {self}
	end
	tracedata.mins = Vector(-30,-30,-20) -- set the mins to cover the leftmost, bottommost, and backmost positions of all three traces
	tracedata.maxs = Vector(30,30,30) -- set the maxs to cover the rightmost, topmost, and frontmost positions of all three traces
	local trace = util.TraceHull(tracedata)

	if trace.HitNonWorld and trace.Entity:IsValid() then
		if self.Exploded then
			return
		end
		if self.TriggeredByOwner or trace.Entity ~= self.ClayOwner then
			self:Explode()
		end
	end

	--self:NextThink( CurTime() + 0.01 )
	--return true
end


function ENT:PhysicsCollide( data, phys )
	if self.Setup or !data.HitEntity:IsWorld() then
		return
	end

	if !data.HitEntity:IsWorld() then
		return
	end

	self:SetMoveType( MOVETYPE_NONE )
	phys:EnableMotion( false )
	phys:Sleep()

	self:SetUpTripMine( data.HitNormal:GetNormal() * -1 )
end

function ENT:Trace()
	local tr = {}
	tr.start = self:GetPos()

	 if self.InitEnt and self.InitEnt:IsValid() then
			 tr.filter = {self, self.InitEnt}
	 else
			tr.filter = {self}
	 end

	return util.TraceLine( tr )
end

function ENT:SetUpTripMine( forward )
		self.Setup = true

		self:SetAngles( forward:Angle() + Angle( 90, 0, 0 ) )
		self:EmitSound( self.StickSound[math.random(1,#self.StickSound)] )
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

ENT.Kids = {}
ENT.Exploding = false
function ENT:OnTakeDamage( DamageInfo )
	if IsValid(self.ClayParent) then
		self.ClayParent:TakeDamage(1, DamageInfo:GetAttacker(), DamageInfo:GetInflictor())
	else
		if table.HasValue(self.Kids, DamageInfo:GetInflictor()) or self.Exploding then
			return
		end
		self.Exploding = true
		for _, kid in pairs(self.Kids) do
			if IsValid(kid) then
				kid:Explode()
			end
		end
		self:Explode()
	end
end

function ENT:Explode()
	if self:GetNWBool("exploded") == true then
		return
	end
	self:SetNWBool("exploded", true)
	self.Exploded = true
	if !IsValid(self) then
		return
	end

	self:EmitSound( "ambient/explosions/explode_4.wav" )
	if IsValid(self.ClayOwner) then
		self:SetOwner(self.ClayOwner)
	end

	local detonate = ents.Create( "env_explosion" )
	detonate:SetPos( self:GetPos() )
	detonate:SetKeyValue( "iMagnitude", "0" )
	detonate:SetKeyValue( "iRadiusOverride", "300" )
	detonate:Spawn()
	detonate:Activate()
	detonate:Fire( "Explode", "", 0 )

	local startDistance = GetConVar("Claymore_Radius"):GetInt()
	local radius = GetConVar("Claymore_Radius"):GetInt()
	local startDamage = GetConVar("Claymore_DamageStartDistance"):GetInt()
	local endDamage = GetConVar("Claymore_DamageEnd"):GetInt()
	local forward = self:GetRight() * -1 -- get the forward vector of the entity
	local entities = ents.FindInSphere(self:GetPos(), radius)

	for _, ent in pairs(entities) do
		local direction = (ent:GetPos() - self:GetPos()):GetNormalized() -- get the direction vector of the ent relative to the entity
		local dotProduct = forward:Dot(direction) -- get the dot product of the forward vector and the direction vector
		if dotProduct > 0 then -- if the dot product is greater than 0, it means the ent is in front of the entity
			local distance = ent:GetPos():Distance(self:GetPos())
			local alpha = (distance - startDistance) / (radius - startDistance)
			alpha = math.Clamp(alpha, 0, 1) -- Clamp alpha between 0 and 1
			local damage = Lerp(alpha, startDamage, endDamage)
			if distance < startDistance then
				damage = startDamage
			end
			if IsValid(self.ClayOwner) then
				ent:TakeDamage(damage, self.ClayOwner, self)
			else
				ent:TakeDamage(damage, game.GetWorld(), self)
			end
			if ent:GetClass() == "prop_physics" and IsValid(ent:GetPhysicsObject()) then
				local force = direction * 500 -- apply force in the opposite direction of the explosion
				ent:GetPhysicsObject():ApplyForceCenter(force)
			end
		end
	end

	local shake = ents.Create( "env_shake" )
	if IsValid(self.ClayOwner) then
		shake:SetOwner( self.ClayOwner )
	end
	shake:SetPos( self:GetPos() )
	shake:SetKeyValue( "amplitude", "2000" )
	shake:SetKeyValue( "radius", "400" )
	shake:SetKeyValue( "duration", "2.5" )
	shake:SetKeyValue( "frequency", "255" )
	shake:SetKeyValue( "spawnflags", "4" )
	shake:Spawn()
	shake:Activate()
	shake:Fire( "StartShake", "", 0 )

	self:Remove()
end

-----------
-- Touch --
-----------
function ENT:Touch(ent)

end

--------------------
-- PhysicsCollide -- 
--------------------
function ENT:PhysicsCollide( data, physobj )
	if !data.HitEntity:IsWorld( ) then return end

	physobj:EnableMotion( false )
	physobj:Sleep( )
end

function ENT:UpdateTransmitState( )
		return TRANSMIT_ALWAYS
end

ENT.CanUse = true
function ENT:Use( activator, caller )
	if activator:IsPlayer() and self.CanUse and self:GetNWString("OwnerID") == activator:SteamID() then
		self.CanUse = false
		if SERVER then
			local ChildClaymoreCount = 0
			for k,v in pairs(self:GetChildren()) do
				if v:GetClass() == self:GetClass() then
					ChildClaymoreCount = ChildClaymoreCount + 1
				end
			end
			if GetConVar("Claymore_Infinite"):GetBool() == false then
				if activator:HasWeapon(self.WeaponClass) then
					activator:GiveAmmo(1, "Slam", true)
				else
					activator:Give(self.WeaponClass)
					activator:SelectWeapon(self.WeaponClass)
					activator:RemoveAmmo(2, "Slam")
				end
				activator:GiveAmmo(ChildClaymoreCount, "Slam", true)
			end
			self:Remove()
		end
	end
end

function ENT:PhysgunPickup(ply, ent)
	if ent:GetClass() == self:GetClass() then
		return false
	end
end
hook.Add("PhysgunPickup", "StopClaymorePhysgun", function(ply, ent)
	if IsValid(ent) and ent.PhysgunPickup then
		return ent:PhysgunPickup(ply, ent)
	end
end)

cvars.AddChangeCallback("Claymore_OwnerTrigger", function(name, old, new)
	local claymoreClasses = {"seal6-claymore-ent", "seal6-claymore-bo2-ent"}
	local triggeredValue = tobool(new)

	for _, className in ipairs(claymoreClasses) do
		for _, entity in ipairs(ents.FindByClass(className)) do
			entity.TriggeredByOwner = triggeredValue
		end
	end
end)