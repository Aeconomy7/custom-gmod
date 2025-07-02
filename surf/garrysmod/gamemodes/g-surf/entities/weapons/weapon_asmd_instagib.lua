-- ASMD Shock Rifle
-- By Anya O'Quinn / Slade Xanthas

AddCSLuaFile()

if SERVER then
	resource.AddWorkshop("218282080")
end

SWEP.Base					= "weapon_base"

SWEP.PrintName				= "ASMD Shock Rifle Insta"	
SWEP.Author					= "Anya O'Quinn"
SWEP.Category				= "Anya O'Quinn"
SWEP.Instructions			= "Left click to fire a beam, right to fire a core.  Hit a core with the beam to make it explode!"

SWEP.Spawnable				= true
SWEP.AdminOnly				= false

SWEP.Slot					= 2
SWEP.SlotPos				= 0
SWEP.AutoSwitchTo			= false
SWEP.AutoSwitchFrom			= false

SWEP.ViewModel				= "models/weapons/v_ut2k4_shock_rifle.mdl"
SWEP.WorldModel				= "models/weapons/w_ut2k4_shock_rifle.mdl"
SWEP.ViewModelFOV			= 55
SWEP.ViewModelFlip			= false

SWEP.DrawAmmo				= true
SWEP.DrawCrosshair			= true

SWEP.HoldType				= "ar2"

SWEP.Primary.Delay			= 0.90
SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= 50
SWEP.Primary.Automatic		= true
SWEP.Primary.Ammo			= "ar2"
SWEP.Primary.Force			= 400
SWEP.Primary.Damage			= 99999
SWEP.Primary.NumShots		= 100	
SWEP.Primary.Cone			= 0

SWEP.Secondary.Delay		= 0.54
SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= true
SWEP.Secondary.Ammo			= "none"

SWEP.AnimReset 				= CurTime()

local ClassName 			= "weapon_asmd"

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
	if IsValid(self.Weapon) then
		self.Weapon:SendWeaponAnim(ACT_VM_DRAW)
		self.Weapon:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
		self.Weapon:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)
	end
	return true
end

function SWEP:Holster()
	return true
end

function SWEP:OnRemove()
end

function SWEP:OnDrop()
end

function SWEP:CreateBeam()

	if IsValid(self.Owner) and IsValid(self.Weapon) then
		
		local bullet = {}	-- Set up the shot
		bullet.Num = self.Primary.NumShots				
		bullet.Src = self.Owner:GetShootPos()			
		bullet.Dir = self.Owner:GetAimVector()			
		bullet.Spread = Vector( self.Primary.Cone / 90, self.Primary.Cone / 90, 0 )		
		bullet.Force = self.Primary.Force				
		bullet.Damage = self.Primary.Damage				
		bullet.AmmoType = self.Primary.Ammo				
		self.Owner:FireBullets( bullet )				
		
		
		local tracedata = {}
		tracedata.start = self.Owner:GetShootPos()
		tracedata.endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * 999999
		tracedata.filter = self.Owner
		tracedata.mins = Vector(-2,-2,-2)
		tracedata.maxs = Vector(2,2,2)
		local tr = util.TraceHull(tracedata)
		
		if tr.Hit then
		
			if IsValid(tr.Entity) then
			
				if SERVER then
			
					local dmginfo = DamageInfo()
					dmginfo:SetAttacker(self.Owner)
					dmginfo:SetInflictor(self.Weapon)
					dmginfo:SetDamage(500)
					dmginfo:SetDamageType(DMG_ENERGYBEAM)
					dmginfo:SetDamagePosition(tr.HitPos)
					tr.Entity:TakeDamageInfo(dmginfo)
					
					local vecSub = tr.HitPos - self.Owner:GetShootPos()
					local vecFinal = vecSub:GetNormalized() * 10000
					local phys = tr.Entity:GetPhysicsObject()	
					
					if IsValid(phys) then
						phys:ApplyForceOffset(vecFinal, tr.HitPos)
					else
						tr.Entity:SetVelocity(vecFinal)
					end
				
				end

				if tr.Entity:GetClass() == "rj_shockcore" and self.Owner:GetAmmoCount(self.Primary.Ammo) >= 5 then
					self.Owner:RemoveAmmo(5, self.Primary.Ammo)
				end
				
			end
			
			if SERVER then
				sound.Play("weapons/physcannon/energy_disintegrate"..math.random(4,5)..".wav",tr.HitPos, 45, 60)
			end
			
			local Pos1 = tr.HitPos + tr.HitNormal * 8
			local Pos2 = tr.HitPos - tr.HitNormal * 8
			util.Decal("fadingscorch", Pos1, Pos2)
			
			if not IsFirstTimePredicted() then return end
			
			local vm = self.Owner:GetViewModel()
			if IsValid(vm) then
				local fx = EffectData()
				fx:SetEntity(self.Weapon)
				fx:SetOrigin(tr.HitPos)
				fx:SetNormal(tr.HitNormal)
				util.Effect("rj_shockbeam", fx, true)	
			end
			
		end
	
	end
	
end

function SWEP:CreateCore()

	if IsValid(self.Owner) and IsValid(self.Weapon) then

		if SERVER then
		
			local ent = ents.Create("rj_shockcore")
			if not ent then return end
			ent.Owner = self.Owner
			ent.Inflictor = self.Weapon
			ent:SetOwner(self.Owner)
			local eyeang = self.Owner:GetAimVector():Angle()
			local right = eyeang:Right()
			local up = eyeang:Up()
			ent:SetPos(self.Owner:GetShootPos() + right * 4 + up)
			ent:SetAngles(self.Owner:GetAngles())
			ent:SetPhysicsAttacker(self.Owner)
			ent:Spawn()
			
			local phys = ent:GetPhysicsObject()
			if IsValid(phys) then				
				phys:SetVelocity(self.Owner:GetAimVector() * 1500)
			end
			
		end
		
		if not IsFirstTimePredicted() then return end
		
		local vm = self.Owner:GetViewModel()
		if IsValid(vm) then
			local fx = EffectData()
			fx:SetEntity(self.Weapon)
			util.Effect("rj_coremuzzle", fx)	
		end
	
	end
	
end

function SWEP:Think()
	if self.AnimReset and self.AnimReset < CurTime() then
		self.Weapon:SendWeaponAnim(ACT_VM_IDLE)
	end
end

function SWEP:CanPrimaryAttack()
	if self.Owner:GetAmmoCount(self.Primary.Ammo) <= 0 or self.Owner:WaterLevel() >= 3 then
		return false
	end
	return true
end

function SWEP:PrimaryAttack()

	if not self:CanPrimaryAttack() then return end
	
	self.Weapon:EmitSound("ut2k4/shockrifle/fire.wav", 100, 100)

	self:CreateBeam()
	self.Owner:RemoveAmmo(1, self.Primary.Ammo)
	self.Weapon:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self.Owner:SetAnimation(PLAYER_ATTACK1)

	self.Weapon:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	self.Weapon:SetNextSecondaryFire(CurTime() + self.Primary.Delay)
	
	self.AnimReset = CurTime() + self.Primary.Delay / 2
	
	if (game.SinglePlayer() and SERVER) or CLIENT then
		self.Weapon:SetNetworkedFloat("LastShootTime", CurTime())
	end

end

function SWEP:SecondaryAttack()

	if not self:CanPrimaryAttack() then return end
	
	self.Weapon:EmitSound("ut2k4/shockrifle/altfire.wav", 90, 100)
	
	self:CreateCore()
	self.Owner:RemoveAmmo(1, self.Primary.Ammo)
	self.Weapon:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self.Owner:SetAnimation(PLAYER_ATTACK1)

	self.Weapon:SetNextPrimaryFire(CurTime() + self.Secondary.Delay)
	self.Weapon:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)
	
	self.AnimReset = CurTime() + self.Secondary.Delay / 2
	
	if (game.SinglePlayer() and SERVER) or CLIENT then
		self.Weapon:SetNetworkedFloat("LastShootTime", CurTime())
	end
	
end

function SWEP:Reload()
	return false
end

local ENT = {}

ENT.Type = "anim"  
ENT.Base = "base_anim"

if CLIENT then

	function ENT:Draw()
		self:DrawModel()	
	end
	
	function ENT:Initialize()
		local fx = EffectData()
		fx:SetEntity(self)
		util.Effect("rj_shockcore",fx,true)
	end
	
end

if SERVER then

	function ENT:Initialize()

		self:SetModel("models/Combine_Helicopter/helicopter_bomb01.mdl")
		self:PhysicsInitBox(Vector(-20,-20,-20),Vector(20,20,20))
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)
		self:SetNoDraw(true)
		self:DrawShadow(false)
		
		local phys = self:GetPhysicsObject()  	
		if IsValid(phys) then 
			phys:Wake()
			phys:EnableDrag(false)
			phys:EnableGravity(false)
			phys:AddGameFlag(FVPHYSICS_NO_IMPACT_DMG)
			phys:AddGameFlag(FVPHYSICS_NO_PLAYER_PICKUP)
			phys:SetMass(50)
			phys:SetBuoyancyRatio(0)
		end

		self.WhirrSound = CreateSound(self, "weapons/physcannon/energy_sing_loop4.wav")
		self.WhirrSound:Play()

		self:Fire("kill", 1, 10)

	end
	
	local dmg = 55
	local radius = 40
	
	function ENT:Think()
	
		if self.Hit then
		
			self:SetMoveType(MOVETYPE_NONE)
			self:SetCollisionGroup(COLLISION_GROUP_NONE)
		
			if not self.Combo then	
				dmg = 55
				radius = 40	
				local fx = EffectData()
				fx:SetOrigin(self:GetPos())
				util.Effect("rj_coreimpact",fx)
			else	
				dmg = 215
				radius = 200
				sound.Play("ut2k4/shockrifle/combo.wav",self:GetPos(), 45, 50)
				
				local fx = EffectData()
				fx:SetOrigin(self:GetPos())
				util.Effect("rj_shockcombo",fx)
			end

			sound.Play("ut2k4/shockrifle/explosion.wav",self:GetPos(), 45, 50)	
			util.ScreenShake(self:GetPos(), radius/2, radius/2, 1, radius)
			
			if IsValid(self.Owner) then
			
				local dmginfo = DamageInfo()
			
				if self.Combo then
					dmginfo:SetDamageType(DMG_DISSOLVE)
				else
					dmginfo:SetDamageType(DMG_ENERGYBEAM)
				end
				
				if IsValid(self.Inflictor) then
					dmginfo:SetInflictor(self.Inflictor)
				else
					dmginfo:SetInflictor(self)
				end
				
				if IsValid(self.Owner) then
					dmginfo:SetAttacker(self.Owner)
				else
					dmginfo:SetAttacker(self)
				end
				
				dmginfo:SetDamage(dmg)
				dmginfo:SetDamageForce(self:GetVelocity():GetNormalized() * 2500)
				
				local victims = ents.FindInSphere(self:GetPos(),radius)
				
				for _,v in pairs(victims) do	
				
					if IsValid(v) and v ~= self and not IsValid(v:GetParent()) then
						
						if self.DamagePos then
							dmginfo:SetDamagePosition(self.DamagePos)
						end

						v:TakeDamageInfo(dmginfo)
						
					end
				end
				
			end

			self:Remove()
			
		end
		
		self:NextThink(CurTime())
		return true
		
	end
	
	function ENT:OnRemove()
		if self.WhirrSound then 
			self.WhirrSound:Stop()
		end
	end
	
	function ENT:PhysicsCollide(data,phys)
	
		if not self.Hit then
		
			local trace = {}
			trace.start = self:GetPos()
			trace.endpos = data.HitPos
			trace.filter = self
			trace.mask = MASK_SHOT
			trace.mins = self:OBBMins()
			trace.maxs = self:OBBMaxs()
			local tr = util.TraceHull(trace)
			
			if tr.Hit and tr.HitSky then self:Remove() end
			self.Hit = true
			
		end
		
	end
	
	local function DamageHook(ent, dmginfo)
		local inflictor = dmginfo:GetInflictor()
		local attacker = dmginfo:GetAttacker()
		local dmgtype = dmginfo:GetDamageType()
		if dmgtype == DMG_ENERGYBEAM and ent:GetClass() == "rj_shockcore" and IsValid(inflictor) and IsValid(attacker) and inflictor:GetClass() == ClassName and attacker:GetAmmoCount(inflictor.Primary.Ammo) >= 5 then
			ent.Owner = attacker
			ent.Inflictor = inflictor
			ent.Hit = true
			ent.Combo = true
		end
	end
	hook.Add("EntityTakeDamage","ShockCoreDamage",DamageHook)
	
	local function DenyCoreMoving(ply, ent)
		if ent:GetClass() == "rj_shockcore" then 
			return false 
		end
	end
	hook.Add("PhysgunPickup", "DenyCorePhysGunning", DenyCoreMoving)
	
end

scripted_ents.Register(ENT, "rj_shockcore", true)

if CLIENT then

	local Beam = {}

	Beam.Mat1 	= Material("trails/laser")
	Beam.Mat2 	= Material("sprites/tp_beam001")
	Beam.Mat3 	= Material("trails/electric")
	Beam.Mat4 	= Material("sprites/physgbeamb")
	Beam.Ring1 	= Material("effects/splashwake1")
	Beam.Ring3 	= Material("sprites/blueglow2")

	function Beam:Init(data)
	
		self.Weapon = data:GetEntity()
		
		if IsValid(self.Weapon) then
			self.Owner = self.Weapon.Owner
		end
		
		self.Normal = data:GetNormal()
		
		if self.Normal then
			self.NormalAng = data:GetNormal():Angle() + Angle(0.01,0.01,0.01)
		end
		
		if not IsValid(self.Owner) or (self.Owner and not self.Owner:GetActiveWeapon()) then
			return false
		end
		
		local vm = self.Owner:GetViewModel()

		if IsValid(GetViewEntity()) and (self.Owner == GetViewEntity()) and IsValid(vm) then
			self.StartPos = vm:GetAttachment(vm:LookupAttachment("muzzle")).Pos
		elseif IsValid(GetViewEntity()) and self.Owner ~= GetViewEntity() and self.Weapon and self.Weapon:LookupAttachment("muzzle") and self.Weapon:GetAttachment(self.Weapon:LookupAttachment("muzzle")) then
			self.StartPos = self.Weapon:GetAttachment(self.Weapon:LookupAttachment("muzzle")).Pos
		elseif IsValid(vm) then
			self.StartPos = vm:GetAttachment(vm:LookupAttachment("muzzle")).Pos + self.Owner:GetAimVector():Angle():Right() * 36 - self.Owner:GetAimVector():Angle():Up() * 36
		end
		
		if not self.StartPos then return false end

		self.EndPos = data:GetOrigin()
		self.Dir = self.EndPos - self.StartPos
		
		self.Width = 3
		self.Shrink = 20
		
		self:SetRenderBoundsWS(self.StartPos, self.EndPos)

		self.FadeDelay = 0.3
		self.FadeTime = CurTime() + self.FadeDelay
		self.DieTime = CurTime() + 1.5
		
		self.Alpha = 255
		self.FadeSpeed = 0.5
		
		self.Emitter = ParticleEmitter(self.StartPos)
		
		for i=1,8 do
		
			local muzz = self.Emitter:Add("effects/combinemuzzle2_dark", self.StartPos)
			
			if muzz then
				muzz:SetColor(150, 100, 255)
				muzz:SetRoll(math.Rand(0, 360))
				muzz:SetDieTime(self.FadeDelay + self.FadeSpeed)
				muzz:SetStartSize(15)
				muzz:SetStartAlpha(255)
				muzz:SetEndSize(0)
				muzz:SetEndAlpha(100)
			end
		
		end
		
		for i=1,8 do
		
			local impact = self.Emitter:Add("effects/blueflare1", self.EndPos)
			
			if impact then	
				impact:SetColor(150, 100, 255)
				impact:SetRoll(math.Rand(0, 360))
				impact:SetDieTime(self.FadeDelay + self.FadeSpeed)
				impact:SetStartSize(10)
				impact:SetStartAlpha(255)
				impact:SetEndSize(0)
				impact:SetEndAlpha(200)
				impact:SetAngles(self.NormalAng)
			end
		
		end

	end

	function Beam:Think()
	
		if self.FadeTime and CurTime() > self.FadeTime then
			self.Alpha = Lerp(13 * self.FadeSpeed * FrameTime(), self.Alpha, 0)
			self.Shrink = Lerp(2 * self.FadeSpeed * FrameTime(), self.Shrink, 0)
		end
	
		if self.DieTime and CurTime() > self.DieTime then
			return false
		end
		
		return true
		
	end

	function Beam:Render()
		if self.Width and self.Alpha then
			self.Width = math.Max(self.Width - 0.5, 0)
			local endPos = self.EndPos
			render.SetMaterial(self.Mat1)
			render.DrawBeam(endPos, self.StartPos, self.Shrink + (self.Width * 10), 1, 0, Color(170, 50, 200, self.Alpha))
			render.SetMaterial(self.Mat2)
			render.DrawBeam(endPos, self.StartPos, self.Shrink * 1.25 + (self.Width * 10), 1, 0, Color(165, 50, 200, self.Alpha))
			render.SetMaterial(self.Mat3)
			render.DrawBeam(endPos, self.StartPos, self.Shrink * 1.5 + (self.Width * 10), 1, 0, Color(165, 50, 200, self.Alpha))
			render.SetMaterial(self.Mat4)
			render.DrawBeam(endPos, self.StartPos, self.Shrink / 7 + (self.Width * 10) , 1, 0, Color(200, 150, 200, self.Alpha))
			render.SetMaterial(self.Ring1)
			render.DrawQuadEasy(self:GetPos(), self.NormalAng:Forward(), 50, 50, Color(165, 150, 200, self.Alpha))
			render.SetMaterial(self.Ring3)
			render.DrawQuadEasy(self:GetPos(), self.NormalAng:Forward(), 50, 50, Color(170, 100, 200, self.Alpha))
		end
	end

	effects.Register(Beam, "rj_shockbeam", true)
	
	local CoreMuzzle = {}
	
	function CoreMuzzle:Init(data)
	
		self.Weapon = data:GetEntity()
		
		if IsValid(self.Weapon) then
			self.Owner = self.Weapon.Owner
		end
		
		if not IsValid(self.Owner) or (self.Owner and not self.Owner:GetActiveWeapon()) then
			return false
		end
		
		local vm = self.Owner:GetViewModel()

		if (self.Owner == GetViewEntity()) and IsValid(vm) then
			self.Pos = vm:GetAttachment(vm:LookupAttachment("muzzle")).Pos
		elseif self.Owner ~= GetViewEntity() and IsValid(self.Weapon) and self.Weapon:LookupAttachment("muzzle") and self.Weapon:GetAttachment(self.Weapon:LookupAttachment("muzzle")) then
			self.Pos = self.Weapon:GetAttachment(self.Weapon:LookupAttachment("muzzle")).Pos
		elseif IsValid(vm) then
			self.Pos = vm:GetAttachment(vm:LookupAttachment("muzzle")).Pos + self.Owner:GetAimVector():Angle():Right() * 36 - self.Owner:GetAimVector():Angle():Up() * 36
		end
		
		if not self.Pos then return false end
		
		self.Emitter = ParticleEmitter(self.Pos)
		
		for i=1,8 do
		
			local muzz = self.Emitter:Add("effects/combinemuzzle2_dark", self.Pos)
			
			if muzz then
				muzz:SetColor(150, 100, 255)
				muzz:SetRoll(math.Rand(0, 360))
				muzz:SetDieTime(0.5)
				muzz:SetStartSize(25)
				muzz:SetStartAlpha(255)
				muzz:SetEndSize(0)
				muzz:SetEndAlpha(100)
			end
		
		end

	end
	
	function CoreMuzzle:Think()
		return false
	end
	
	function CoreMuzzle:Render()	
	end
	
	effects.Register(CoreMuzzle, "rj_coremuzzle", true)
	
	local Combo = {}
	
	function Combo:Init(data)
	
		self.Grow = 0
		self.GrowSpeed = 6
		self.GrowDieTime = CurTime() + 0.20
		self.GrowModelScale = 0
		
		self.Shrink = 25
		self.ShrinkSpeed = 1.2
		self.ShrinkDieTime = CurTime() + 1.5
		self.ShrinkModelScale = 1
		
		self.OriginalScale = self:GetModelScale()

		self.CSShrinkModel = ClientsideModel("models/dav0r/hoverball.mdl", RENDER_GROUP_VIEW_MODEL_OPAQUE)
		if IsValid(self.CSShrinkModel) then
			self.CSShrinkModel:SetPos(data:GetOrigin())
			self.CSShrinkModel:SetNoDraw(true)
		end
		
		self.CSGrowModel = ClientsideModel("models/dav0r/hoverball.mdl", RENDER_GROUP_VIEW_MODEL_OPAQUE)
		if IsValid(self.CSGrowModel) then
			self.CSGrowModel:SetPos(data:GetOrigin())
			self.CSGrowModel:SetNoDraw(true)
		end
		
		local vOrig = data:GetOrigin()
		
		self.Emitter = ParticleEmitter(vOrig)
		
		for i=1,4 do
		
			local flash = self.Emitter:Add("particle/Particle_Glow_04", vOrig)
			
			if flash then
				flash:SetColor(200, 150, 255)
				flash:SetRoll(math.Rand(0, 360))
				flash:SetDieTime(0.40)
				flash:SetStartSize(100)
				flash:SetStartAlpha(255)
				flash:SetEndSize(220)
				flash:SetEndAlpha(0)
			end
			
			local flash2 = self.Emitter:Add("particle/Particle_Glow_05_AddNoFog", vOrig)
			
			if flash2 then
				flash2:SetColor(200, 150, 255)
				flash2:SetRoll(math.Rand(0, 360))
				flash2:SetDieTime(1.5)
				flash2:SetStartSize(180)
				flash2:SetStartAlpha(255)
				flash2:SetEndSize(0)
				flash2:SetEndAlpha(100)
			end
		
		end
		
		for i=1,24 do

			local flash3 = self.Emitter:Add("effects/stunstick", vOrig)
			
			if flash3 then
				flash3:SetColor(225, 150, 255)
				flash3:SetRoll(math.Rand(0, 360))
				flash3:SetVelocity(VectorRand():GetNormal() * math.random(300, 600))
				flash3:SetRoll(math.Rand(0, 360))
				flash3:SetRollDelta(math.Rand(-2, 2))
				flash3:SetDieTime(0.15)
				flash3:SetStartSize(40)
				flash3:SetStartAlpha(255)
				flash3:SetEndSize(120)
				flash3:SetEndAlpha(0)
			end
			
		end

	end
	
	function Combo:Think()
	
		self.Shrink = Lerp(2 * self.ShrinkSpeed * FrameTime(), self.Shrink, 0)
		self.Grow = Lerp(2 * self.GrowSpeed * FrameTime(), self.Grow, 37)
		self.ShrinkModelScale = self.OriginalScale * self.Shrink
		self.GrowModelScale = self.OriginalScale * self.Grow
		
		if self.GrowDieTime and CurTime() > self.GrowDieTime then
			if IsValid(self.CSGrowModel) then
				self.CSGrowModel:Remove()
			end		
		end

		if self.ShrinkDieTime and CurTime() > self.ShrinkDieTime then
			if IsValid(self.CSShrinkModel) then
				self.CSShrinkModel:Remove()
			end
			return false
		end	
		
		return true
		
	end
	
	function Combo:Render()
	
		if IsValid(self.CSShrinkModel) then
			render.SuppressEngineLighting(true)
			render.SetColorModulation(150/255, 75/255, 1)
			render.SetBlend(1)
			self.CSShrinkModel:DrawModel()
			render.SuppressEngineLighting(false)
			render.SetBlend(1)
			render.SetColorModulation(1,1,1)
			self.CSShrinkModel:SetModelScale(self.ShrinkModelScale,0)	
			self.CSShrinkModel:SetMaterial("models/alyx/emptool_glow")
		end
		
		if IsValid(self.CSGrowModel) then
			render.SuppressEngineLighting(true)
			render.SetColorModulation(100/255, 50/255, 1)
			render.SetBlend(1)
			self.CSGrowModel:DrawModel()
			render.SuppressEngineLighting(false)
			render.SetBlend(1)
			render.SetColorModulation(1,1,1)
			self.CSGrowModel:SetModelScale(self.GrowModelScale,0)
			self.CSGrowModel:SetMaterial("models/alyx/emptool_glow")
		end
		
	end
	
	effects.Register(Combo, "rj_shockcombo", true)
	
	local Core = {}
	
	function Core:Init(data)
		self.LastFlash = CurTime()
		if not IsValid(data:GetEntity()) then return end
		self.Ent = data:GetEntity()
		self.Emitter = ParticleEmitter(self.Ent:GetPos())
		if IsValid(self.Ent) then
			self:SetParent(self.Ent)
		end
	end
	
	function Core:Think()
		
		if not IsValid(self.Ent) or (IsValid(self.Ent) and self.Ent.Hit) then return false end
	
		if IsValid(self.Ent) and not self.Ent.Hit and self.LastFlash < CurTime() then
	
			for i=1,3 do

				local corona = self.Emitter:Add("effects/rollerglow", self.Ent:GetPos())
				
				if corona then
					corona:SetColor(225, 40, 80)
					corona:SetRoll(math.Rand(0, 360))
					corona:SetVelocity(VectorRand():GetNormal() * math.random(0, 20))
					corona:SetRoll(math.Rand(0, 360))
					corona:SetRollDelta(math.Rand(-2, 2))
					corona:SetDieTime(0.01 + FrameTime())
					corona:SetStartSize(82.5)
					corona:SetStartAlpha(150)
					corona:SetEndAlpha(150)
					corona:SetEndSize(82.5)
				end
				
				local rot = self.Emitter:Add("particle/particle_ring_wave_8", self.Ent:GetPos())
				
				if rot then
					rot:SetColor(125, 75, 170)
					rot:SetRoll(math.Rand(0, 360))
					rot:SetVelocity(VectorRand():GetNormal() * math.random(0, 20))
					rot:SetRoll(math.Rand(0, 360))
					rot:SetRollDelta(math.Rand(-2, 2))
					rot:SetDieTime(0.01 + FrameTime())
					rot:SetStartSize(50)
					rot:SetStartAlpha(150)
					rot:SetEndAlpha(150)
					rot:SetEndSize(50)
				end
				
				local glow = self.Emitter:Add("particle/Particle_Glow_04", self.Ent:GetPos())
				
				if glow then
					glow:SetColor(210, 200, 255)
					glow:SetRoll(math.Rand(0, 360))
					glow:SetVelocity(VectorRand():GetNormal() * math.random(0, 20))
					glow:SetRoll(math.Rand(0, 360))
					glow:SetRollDelta(math.Rand(-2, 2))
					glow:SetDieTime(0.01 + FrameTime())
					glow:SetStartSize(20)
					glow:SetStartAlpha(200)
					glow:SetEndAlpha(255)
					glow:SetEndSize(20)
				end
				
				local glow_add = self.Emitter:Add("particle/Particle_Glow_05_AddNoFog", self.Ent:GetPos())
				
				if glow_add then
					glow_add:SetColor(210, 170, 255)
					glow_add:SetRoll(math.Rand(0, 360))
					glow_add:SetVelocity(VectorRand():GetNormal() * math.random(0, 20))
					glow_add:SetRoll(math.Rand(0, 360))
					glow_add:SetRollDelta(math.Rand(-2, 2))
					glow_add:SetDieTime(0.01 + FrameTime())
					glow_add:SetStartSize(75)
					glow_add:SetStartAlpha(255)
					glow_add:SetEndAlpha(255)
					glow_add:SetEndSize(75)
				end

			end
			
			self.LastPuff = CurTime() + 0.03
			
		end

		return true
		
	end

	function Core:Render()
	end
	
	effects.Register(Core, "rj_shockcore", true)
	
	local CoreImpact = {}
	
	function CoreImpact:Init(data)
	
		local vOrig = data:GetOrigin()
	
		self.Emitter = ParticleEmitter(vOrig)
	
		for i=1,8 do
		
			local flash = self.Emitter:Add("effects/blueflare1", vOrig)
			
			if flash then	
				flash:SetColor(150, 100, 255)
				flash:SetVelocity(VectorRand():GetNormal() * math.random(0, 20))
				flash:SetRoll(math.Rand(0, 360))
				flash:SetDieTime(0.5)
				flash:SetStartSize(30)
				flash:SetStartAlpha(255)
				flash:SetEndSize(0)
				flash:SetEndAlpha(0)
			end
		
		end

	end
	
	function CoreImpact:Think()
		return false
	end
	
	function CoreImpact:Render()
	end
	
	effects.Register(CoreImpact, "rj_coreimpact", true)

end

-- 37062385