if SERVER then
    -- You can make this a ConVar if you want it to be configurable
    local DOUBLEJUMP_POWER = 185
    local BHOP_SPEED_CAP = 600

    hook.Add("KeyPress", "BunnyDoubleJump", function(ply, key)
        if key ~= IN_JUMP then return end

        -- Don't affect spectators or dead players
        local isSpectator = (ply:GetObserverMode() > OBS_MODE_NONE) or false
        if not ply:Alive() or ply:WaterLevel() > 0 or isSpectator then return end

        ply.ulxJumpCount = ply.ulxJumpCount or 0
        ply.ulxJumpReleased = ply.ulxJumpReleased or true

        if ply:IsOnGround() then
            ply.ulxJumpCount = 0
        end

        -- Only allow jump if jump was released after landing
        if not ply.ulxJumpReleased then return end

        if ply.ulxJumpCount == 0 then
            ply.ulxJumpCount = 1
            ply.ulxJumpReleased = false
        elseif ply.ulxJumpCount == 1 then
            local vel = ply:GetVelocity()
            local addZ = DOUBLEJUMP_POWER - vel.z
            ply:SetVelocity(Vector(0, 0, addZ))
            ply.ulxJumpCount = 2
            ply.ulxJumpReleased = false
        end
    end)

    hook.Add("KeyRelease", "BunnyDoubleJumpRelease", function(ply, key)
        -- local isSpectator = (ply:GetObserverMode() > OBS_MODE_NONE) or false
        -- if key ~= IN_JUMP or not ply:Alive() or isSpectator then return end
        if key ~= IN_JUMP then return end
        ply.ulxJumpReleased = true
    end)

    hook.Add("OnPlayerHitGround", "ResetBunnyDoubleJump", function(ply)
        local isSpectator = (ply:GetObserverMode() > OBS_MODE_NONE) or false
        if not ply:Alive() or isSpectator then return end
        ply.ulxJumpCount = 0
        ply.ulxJumpReleased = true
    end)

    -- Auto bhop AFTER jump or double jump
    hook.Add("SetupMove", "AutoBhopFix", function(ply, mv)
        local isSpectator = (ply:GetObserverMode() > OBS_MODE_NONE) or false
        if not ply:Alive() or ply:WaterLevel() > 0 or isSpectator then return end
        if mv:KeyDown(IN_JUMP) and not ply:IsOnGround() then
            mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP)))
        end
    end)

    hook.Add("Tick", "ULX_BhopVelocityCap", function()
        for _, ply in ipairs(player.GetAll()) do
            if ply:KeyDown(IN_JUMP) then
                local vel = ply:GetVelocity()
                local horizSpeed = Vector(vel.x, vel.y, 0):Length()
                if horizSpeed > BHOP_SPEED_CAP then
                    local scale = BHOP_SPEED_CAP / horizSpeed
                    ply:SetVelocity(Vector(vel.x * scale - vel.x, vel.y * scale - vel.y, 0))
                end
            end
        end
    end)
end