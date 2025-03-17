if SERVER then
    AddCSLuaFile( "shared.lua" )
    -- AddCSLuaFile( "cl_init.lua" )
    resource.AddWorkshop("794651430")
    resource.AddFile("sound/mjow.wav")
    resource.AddFile("sound/annie-are-you-ok.wav")
    resource.AddFile("sound/annie-are-you-ok.mp3")
    resource.AddFile("sound/thrilcut.wav")
 end

--  include("cl_init.lua")
 
 SWEP.HoldType              = "pistol"
 
 if CLIENT then
    SWEP.PrintName          = "Thriller"
    SWEP.Slot               = 6
 
    SWEP.ViewModelFlip      = false
    SWEP.ViewModelFOV       = 54
    
    SWEP.EquipMenuData = {
       type = "item_weapon",
       desc = "1 Shot.\n\nCauses victim to dance uncontrollably, and sing Thriller, \nthen die 14 seconds later."
    };
 
    SWEP.Icon = "vgui/ttt/icon_thrillerblue.png"
 end
 
 SWEP.Base                  = "weapon_tttbase"
 
 SWEP.Kind                  = WEAPON_PISTOL
 SWEP.WeaponID              = AMMO_PISTOL
 
 SWEP.Primary.Recoil        = 3
 SWEP.Primary.Damage        = 1
 SWEP.Primary.Delay         = 1
 SWEP.Primary.Cone          = 0.01
 SWEP.Primary.ClipSize      = 1
 SWEP.Primary.Automatic     = false
 SWEP.Primary.DefaultClip   = 1
 SWEP.Primary.ClipMax       = 1
 SWEP.Primary.Ammo          = "none"
 SWEP.AmmoEnt               = "none"
 SWEP.AutoSpawnable         = false
 
 SWEP.UseHands              = true
 SWEP.ViewModel             = "models/weapons/cstrike/c_pist_fiveseven.mdl"
 SWEP.WorldModel            = "models/weapons/w_pist_fiveseven.mdl"
 
 SWEP.Kind = WEAPON_EQUIP1
 SWEP.CanBuy = {ROLE_TRAITOR}
 SWEP.LimitedStock = true
 
 SWEP.IronSightsPos         = Vector(-5.95, -1, 4.799)
 SWEP.IronSightsAng         = Vector(0, 0, 0)
 
 function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end
    self.Owner:EmitSound("mjow.wav", 75, 100, 0.5)
    local cone = self.Primary.Cone
    local num = 1
 
    local bullet = {}
    bullet.Num    = num
    bullet.Src    = self.Owner:GetShootPos()
    bullet.Dir    = self.Owner:GetAimVector()
    bullet.Spread = Vector( cone, cone, 0 )
    bullet.Tracer = 1
    bullet.Force	= 10
    bullet.Damage = 1
    bullet.TracerName = "PhyscannonImpact"
    
    bullet.Callback = function(att, tr)
        if SERVER or (CLIENT and IsFirstTimePredicted()) then
            -- util.AddNetworkString("ShowHitMessage")
            local ent = tr.Entity
                if SERVER and ent:IsPlayer() then
                    ent:EmitSound("annie-are-you-ok.mp3")
                    ent:GodEnable()
                    local timerName = "reDance" .. math.random(1,999999)
                    timer.Create( timerName, 1, 17, function()
                    local danceChange = math.random(1, 2)
                    if danceChange == 1 then
                        ent:DoAnimationEvent( ACT_GMOD_GESTURE_TAUNT_ZOMBIE, 1641 )
                    else
                        ent:DoAnimationEvent( ACT_GMOD_TAUNT_DANCE, 1642 )
                    end
                    if !ent:IsFrozen() then ent:Freeze(true) end
                    end)
                    ent:Freeze(true)
                    timer.Simple( 17, function() 
                        if ent:Alive() then
                        ent:GodDisable()
                        ent:Freeze(false)
                        local totalHealth = ent:Health()
                        local inflictWep = ents.Create('weapon_ttt_thriller')
                        ent:TakeDamage( 500, att, inflictWep )
                        timer.Simple( 2, function() if ent:IsFrozen() then ent:Freeze(false) end end)
                        end
                    end)
                    
                    -- net.Start("ShowHitMessage")
                    -- net.Send(ent)
                end
            end
        end
    self.Owner:FireBullets( bullet )
    if SERVER then
      self:TakePrimaryAmmo( 1 )
    end
 end
 
 function SWEP:OnDrop()
     self:Remove()
 end
             
