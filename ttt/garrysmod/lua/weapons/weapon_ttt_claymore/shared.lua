if SERVER then
    AddCSLuaFile("shared.lua")
    resource.AddFile("models/hoff/weapons/claymore/c_claymore.mdl")
    resource.AddFile("models/hoff/weapons/claymore/w_claymore.mdl")
end

-- DEFINE_BASECLASS("weapon_tttbase")

if CLIENT then
    SWEP.PrintName = "Claymore"
    SWEP.Slot = 7

    SWEP.ViewModelFlip = false
    SWEP.ViewModelFOV = 70

    SWEP.EquipMenuData = {
        type = "item_weapon",
        name = "Claymore",
        desc = "A claymore to plant and nurture.\n\nLeft click to plant.\nRight click to detonate.",
    }

    SWEP.Icon = "vgui/ttt/icon_claymore"
    SWEP.IconLetter = "C"
end

SWEP.Base = "weapon_tttbase"
SWEP.Author = "Hoff"
SWEP.PrintName = "Claymore"
SWEP.Instructions = "Plant an explosive claymore trap."
SWEP.Category = "TTT2 (Traitor)"
SWEP.Spawnable = true
SWEP.AdminSpawnable = true
SWEP.ViewModel = "models/hoff/weapons/claymore/c_claymore.mdl"
SWEP.WorldModel = "models/hoff/weapons/claymore/w_claymore.mdl"
SWEP.ViewModelFOV = 70

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.ClipMax = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "slam"
SWEP.Primary.Delay = 0.5

-- SWEP.Secondary.ClipSize = 1
-- SWEP.Secondary.DefaultClip = 1
-- SWEP.Secondary.Automatic = false
-- SWEP.Secondary.Ammo = "none"

SWEP.Weight = 5
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = false
SWEP.UseHands = true
SWEP.HoldType = "slam"
SWEP.AutoSpawnable = false
SWEP.AllowDrop = true

SWEP.Kind = WEAPON_EQUIP1
SWEP.CanBuy = {ROLE_TRAITOR}
SWEP.LimitedStock = true
SWEP.EquipMenuData = {
    type = "Weapon",
    desc = "Plant an explosive claymore that triggers when enemies get near."
}
SWEP.Icon = "vgui/ttt/icon_claymore"

SWEP.ClaymoreEntClass = "seal6-claymore-ent"

SWEP.Offset = {
	Pos = {
		Up = 7,
		Right = 8,
		Forward = 3.5,
	},
	Ang = {
		Up = 90,
		Right = 180,
		Forward = 0,
	}
}
-- WEPS.Register(SWEP, "seal6-claymore")
function SWEP:DrawWorldModel( )
	if not IsValid( self:GetOwner() ) then
		self:DrawModel( )
		return
	end

	local bone = self:GetOwner():LookupBone( "ValveBiped.Bip01_R_Hand" )
	if not bone then
		self:DrawModel( )
		return
	end

	local pos, ang = self:GetOwner():GetBonePosition( bone )
	pos = pos + ang:Right() * self.Offset.Pos.Right + ang:Forward() * self.Offset.Pos.Forward + ang:Up() * self.Offset.Pos.Up
	ang:RotateAroundAxis( ang:Right(), self.Offset.Ang.Right )
	ang:RotateAroundAxis( ang:Forward(), self.Offset.Ang.Forward )
	ang:RotateAroundAxis( ang:Up(), self.Offset.Ang.Up )

	self:SetRenderOrigin( pos )
	self:SetRenderAngles( ang )

	self:DrawModel()
end

function SWEP:Deploy()
	self:SetNWString("CanMelee",true)
	self.Next = CurTime()
	self.Primed = 0
	self:SendWeaponAnim(ACT_VM_DRAW)
	self:SetHoldType("Slam")

	return true
end

function SWEP:Initialize()
	self:SetWeaponHoldType("fist")
end

function SWEP:Equip(NewOwner)
end

function SWEP:Holster()
	self.Next = CurTime()
	self.Primed = 0
	return true
end

function SWEP:PrimaryAttack()
	timer.Simple(0.1, function()
		if IsValid(self) and IsValid(self:GetOwner()) then
			self:GetOwner():StripWeapon("seal6-claymore")
		end
	end)

	if self.Next < CurTime() and self.Primed == 0 then
		self.Next = CurTime() + self.Primary.Delay

		self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
		self.Primed = 1
	end
end

function SWEP:SecondaryAttack()
end

function SWEP:DeployShield()
	if not SERVER then
		return
	end

	-- UNCOMMENT FOR INFINITE CLAYMER ZZZ
	-- if GetConVar("Claymore_Infinite"):GetInt() == 0 then
	self:GetOwner():RemoveAmmo(1,"slam")
	-- end

	timer.Simple(0.4,function()
		if self:IsValid() then

			local ent = ents.Create(self.ClaymoreEntClass)
			local TraceStart = self:GetOwner():GetPos() + Vector(0,0,75)

			local ForwardTrace = util.TraceHull({
				start = TraceStart,
				endpos = TraceStart + self:GetOwner():GetForward() * 30,
				mins = Vector(-5, -5, 0),
				maxs = Vector(5, 5, 0),
				filter = function(FilterEnt)
					if FilterEnt:GetClass() == "player" and FilterEnt == self:GetOwner() then
						return false
					end
					return true
				end
			})

			local NewTraceEnd = TraceStart + self:GetOwner():GetForward() * 30
			if ForwardTrace.Hit then
				NewTraceEnd = ForwardTrace.HitPos + self:GetOwner():GetForward() * -5
			end

			local trace = util.TraceLine({
				start = NewTraceEnd,
				endpos = NewTraceEnd + Vector(0, 0, -200),
				filter = function(FilterEnt)
					if not IsValid(FilterEnt) then
						return false
					end
					if FilterEnt:GetClass() == "player" and FilterEnt == self:GetOwner() then
						return false
					end
					return true
				end
			})


			if trace.Hit then
				if trace.Entity:GetClass() == "seal6-claymore-ent" then
					if IsValid(trace.Entity.ClayParent) then
						ent.ClayParent = trace.Entity.ClayParent
						ent:SetCollisionGroup(COLLISION_GROUP_WEAPON)
					else
						ent.ClayParent = trace.Entity
					end
					table.insert(ent.ClayParent.Kids, table.Count(ent.ClayParent.Kids) + 1, ent)
				end
				ent:SetPos(trace.HitPos)
				local StartAngle = self:GetOwner():GetAngles() + Angle(0,-90,0)
				ent:SetAngles(StartAngle)
			else
				ent:SetPos(self:GetOwner():GetPos())
				ent:SetAngles(Angle(self:GetOwner():GetAngles().x,self:GetOwner():GetAngles().y,self:GetOwner():GetAngles().z) + Angle(0,-90,0))
			end
			ent:Spawn()
			ent.ClayOwner = self:GetOwner()
			ent:SetNWString("OwnerID", self:GetOwner():SteamID())
			ent:EmitSound("hoff/mpl/seal_claymore/plant.wav")
			if engine.ActiveGamemode() ~= "nzombies" then
				undo.Create("Claymore")
					undo.AddEntity(ent)
					undo.SetPlayer(self:GetOwner())
				undo.Finish()

				self:GetOwner():AddCount("sents", ent) -- Add to the SENTs count ( ownership )
				self:GetOwner():AddCount("my_props", ent) -- Add count to our personal count
				self:GetOwner():AddCleanup("sents", ent) -- Add item to the sents cleanup
				self:GetOwner():AddCleanup("my_props", ent) -- Add item to the cleanup
			end
			timer.Simple(0.1, function()
				if IsValid(self:GetOwner()) and self:GetOwner():GetAmmoCount(self.Primary.Ammo) <= 0 then
					self:GetOwner():StripWeapon("seal6-claymore")
				end
			end)
		end
	end)
end

function SWEP:Think()
	if self.Next < CurTime() then
		if self.Primed == 1 and not self:GetOwner():KeyDown(IN_ATTACK) then
--			self.Weapon:SendWeaponAnim(ACT_VM_THROW)
			self:GetOwner():SetAnimation(ACT_VM_PRIMARYATTACK)
			self.Primed = 2
			self.Next = CurTime() + .3
		elseif self.Primed == 2 then
			self.Primed = 0
			self:DeployShield()
			self:GetOwner():SetAnimation(PLAYER_ATTACK1)
			self:SendWeaponAnim(ACT_VM_THROW)
			self.Next = CurTime() + 1.5
		end
	end
end

function SWEP:ShouldDropOnDie()
	return true
end

-- -- Override the Ammo1 function to always return 1
-- function SWEP:Ammo1()
-- 	return self:GetOwner():GetAmmoCount(self.Primary.Ammo)
-- end