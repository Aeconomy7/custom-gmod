if SERVER then
    AddCSLuaFile("cl_init.lua")
    AddCSLuaFile("shared.lua")
end

DEFINE_BASECLASS("ttt_c4")

ENT.Base      = "ttt_c4"
ENT.PrintName = "Plant & Defuse Bomb"

if SERVER then
    util.AddNetworkString("TTT_C4PDDisarmResult")
end

local MAX_MOVE_RANGE = 1000000

-- Identical to ttt_c4 Think but without the beep sound
function ENT:Think()
    if not self:GetArmed() then return end

    if SERVER then
        local curpos = self:GetPos()
        if self.LastPos and self.LastPos:DistToSqr(curpos) > MAX_MOVE_RANGE then
            self:Disarm(nil)
            return
        end
        self.LastPos = curpos
    end

    local etime = self:GetExplodeTime()
    if etime ~= 0 and etime < CurTime() then
        local spos = self:GetPos()
        local tr = util.TraceLine({
            start  = spos,
            endpos = spos + Vector(0, 0, -32),
            mask   = MASK_SHOT_HULL,
            filter = self:GetThrower(),
        })
        local ok, err = pcall(self.Explode, self, tr)
        if not ok then
            self:Remove()
            ErrorNoHaltWithStack("ERROR CAUGHT: ttt_c4_pd: " .. err .. "\n")
        end
    end
    -- No beeping
end

-- No damage or explosion effects; just fire the hook and clean up
function ENT:Explode(tr)
    local result, message = hook.Run("TTTC4Explode", self)
    if result == false then
        -- Reset ExplodeTime so Think does not re-fire Explode every tick
        if SERVER then self:SetExplodeTime(0) end
        if SERVER and message then
            LANG.Msg(self:GetThrower(), message, nil, MSG_MSTACK_WARN)
        end
        return
    end

    if SERVER then
        self:SetNoDraw(true)
        self:SetSolid(SOLID_NONE)
        self:SetExplodeTime(0)
        events.Trigger(EVENT_C4EXPLODE, self:GetThrower())
        self:Remove()
    else
        self:SetExplodeTime(0)
    end
end

if SERVER then
    -- BaseClass.Disarm calls events.Trigger(EVENT_C4DISARM, GetOriginator(), ply, true).
    -- If GetOriginator() is nil, c4disarm.lua crashes on :SteamID64().
    -- Guard it and fall back to direct state clear.
    function ENT:Disarm(ply)
        if IsValid(self:GetOriginator()) then
            BaseClass.Disarm(self, ply)
        else
            self:SetExplodeTime(0)
            self:SetArmed(false)
            self:RemoveMarkerVision("c4_owner")
        end
    end

    -- Always make every wire safe regardless of arm time.
    -- ply must be a valid player for BaseClass.Arm; if not, set state directly.
    function ENT:Arm(ply, time)
        if IsValid(ply) and ply:IsPlayer() then
            BaseClass.Arm(self, ply, time)
        else
            self:SetDetonateTimer(time)
            self:SetArmTime(CurTime())
            self:SetArmed(true)
            self.DisarmCausedExplosion = false
        end
        self.safeWires = {}
        for i = 1, C4_WIRE_COUNT do
            self.safeWires[i] = true
        end
        -- Freeze in place so bullets/props cannot move the armed bomb
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:Sleep()
        end
    end

    local function ReceiveC4PDDisarm(ply, cmd, args)
        if not (IsValid(ply) and ply:IsTerror() and #args == 2) then return end

        local idx  = tonumber(args[1])
        local wire = tonumber(args[2])
        if not idx or not wire then return end

        local bomb = ents.GetByIndex(idx)
        if not (
            IsValid(bomb)
            and bomb:GetClass() == "ttt_c4_pd"
            and not bomb.DisarmCausedExplosion
            and bomb:GetArmed()
            and bomb:GetPos():Distance(ply:GetPos()) <= 256
        ) then return end

        -- Only defusers may disarm
        if TEAM_DEFUSER and ply:GetTeam() ~= TEAM_DEFUSER then return end

        local result, message = hook.Run("TTTC4Disarm", bomb, true, ply)
        if result == false then
            if message then LANG.Msg(ply, message, nil, MSG_MSTACK_WARN) end
            return
        end

        -- All wires are safe in plant_and_defuse; always succeed
        LANG.Msg(ply, "c4_disarmed")
        bomb:Disarm(ply)

        net.Start("TTT_C4PDDisarmResult")
            net.WriteEntity(bomb)
            net.WriteBool(true)
        net.Send(ply)
    end
    concommand.Add("ttt_c4_pd_disarm", ReceiveC4PDDisarm)
end
