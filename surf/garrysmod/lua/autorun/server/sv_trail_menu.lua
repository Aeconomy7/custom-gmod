util.AddNetworkString("OpenTrailMenu")
util.AddNetworkString("SelectTrail")

include("autorun/server/sv_trail_config.lua")

-- Cleanup any old trails on player
local function ClearPlayerTrail(ply)
    if IsValid(ply.trail) then
        ply.trail:Remove()
    end
end

-- Apply selected trail
local function ApplyTrail(ply, trailData)
    ClearPlayerTrail(ply)

    if not IsValid(ply) then return end

    -- Remove existing trail
    if IsValid(ply.trail) then
        ply.trail:Remove()
        ply.trail = nil
    end

    -- Handle "no trail" case
    if not trailData or trailData.Material == "none" then
        ply:SetPData("selected_trail", "none")
        return
    end

    local length = math.Clamp(trailData.Length or 2, 0.1, 10)
    local startSize = math.Clamp(trailData.StartSize or 32, 0, 128)
    local endSize = math.Clamp(trailData.EndSize or 0, 0, 128)
    if startSize <= 0 and endSize <= 0 then return end

    startSize = math.max(0.0001, startSize)
    local color = trailData.Color or Color(255, 255, 255)
    local material = trailData.Material or "none"

    if not trailData or trailData.Material == "none" then
        ply:SetPData("selected_trail", "none")
        return
    end

    local trailEnt = util.SpriteTrail(
        ply,
        0,
        color,
        false,
        startSize,
        endSize,
        length,
        1 / ((startSize + endSize) * 0.5),
        material .. ".vmt"
    )

    ply.trail = trailEnt
    ply:SetPData("selected_trail", material)
    ply:SetPData("selected_trail_color_r", color.r)
    ply:SetPData("selected_trail_color_g", color.g)
    ply:SetPData("selected_trail_color_b", color.b)
    ply:SetPData("selected_trail_start_size", startSize)
    ply:SetPData("selected_trail_end_size", endSize)
    ply:SetPData("selected_trail_length", length)
    

end

-- Show menu with !trail
hook.Add("PlayerSay", "TrailChatCommand", function(ply, text)
    if string.lower(text) == "!trail" then
        if not TrailOptions or #TrailOptions == 0 then
            ply:ChatPrint("No trails available.")
            return ""
        end

        net.Start("OpenTrailMenu")
        net.WriteTable(TrailOptions)
        net.Send(ply)
        return ""
    end
end)

-- Handle client selection
net.Receive("SelectTrail", function(_, ply)
    local trailMat = net.ReadString()
    local r = net.ReadUInt(8)
    local g = net.ReadUInt(8)
    local b = net.ReadUInt(8)
    local startSize = net.ReadUInt(8)
    local endSize = net.ReadUInt(8)
    local length = net.ReadUInt(8)

    local trailData = {
        Material = trailMat,
        StartSize = startSize,
        EndSize = endSize,
        Length = length,
        Color = Color(r, g, b)
    }

    ApplyTrail(ply, trailData)

    if trailMat == "none" then
        ply:ChatPrint("Trail disabled.")
    else
        ply:ChatPrint("Trail set to: " .. trailMat)
    end
end)

-- Re-apply trail on spawn
hook.Add("PlayerSpawn", "GiveSelectedTrail", function(ply)
    timer.Simple(1, function()
        if not IsValid(ply) then return end

        local startSize = tonumber(ply:GetPData("selected_trail_start_size")) or 32
        local endSize = tonumber(ply:GetPData("selected_trail_end_size")) or 0
        local trailLen = tonumber(ply:GetPData("selected_trail_length")) or 15
        local r = tonumber(ply:GetPData("selected_trail_color_r")) or 255
        local g = tonumber(ply:GetPData("selected_trail_color_g")) or 255
        local b = tonumber(ply:GetPData("selected_trail_color_b")) or 255
        local savedTrail = ply:GetPData("selected_trail")
        if not savedTrail or savedTrail == "none" then return end

        ApplyTrail(ply, {
            Material = savedTrail,
            StartSize = startSize,
            EndSize = endSize,
            Length = trailLen,
            Color = Color(r, g, b)
        })
    end)
end)