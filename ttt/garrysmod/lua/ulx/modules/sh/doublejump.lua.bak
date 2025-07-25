if SERVER then
    util.AddNetworkString("ulx_doublejump_enable")

    -- Allow admins to enable/disable double jump for players
    function ulx.doublejump(calling_ply, target_plys, should_disable, power)
        power = power or 225
        
        for _, ply in ipairs(target_plys) do
            local state = should_disable and 0 or 1
            ply:SetNWInt("doublejump", state)
            ply:SetNWInt("doublejump_power", power) -- Store the power value if needed
        end

        if not should_disable then
            ulx.fancyLogAdmin(calling_ply, "#A enabled double jump for #T with power #s", target_plys, power)
        else
            ulx.fancyLogAdmin(calling_ply, "#A disabled double jump for #T", target_plys)
        end
    end

    local doublejump = ulx.command("Fun", "ulx doublejump", ulx.doublejump, "!doublejump")
    doublejump:addParam{ type=ULib.cmds.PlayersArg }
    doublejump:addParam{ type=ULib.cmds.NumArg, min=1, max=1000, default=185, ULib.cmds.optional, hint="power" }
    doublejump:defaultAccess(ULib.ACCESS_ADMIN)
    doublejump:help("Enable or disable double jump for players. Optionally set jump power (default 185).")
    doublejump:setOpposite("ulx nodoublejump", {_, _, true}, "!nodoublejump")

    -- The actual double jump logic
    hook.Add("KeyPress", "ULX_DoubleJump", function(ply, key)
        if key ~= IN_JUMP then return end
        if ply:GetNWInt("doublejump", 0) ~= 1 then return end
        if not ply:Alive() or ply:WaterLevel() > 0 then return end

        -- Only allow double jump if not on ground and hasn't already double jumped
        if not ply.ulxDoubleJumped and not ply:IsOnGround() then
            local power = ply:GetNWInt("doublejump_power", 185)

            local vel = ply:GetVelocity()
            local desiredZ = power
            local addZ = desiredZ - vel.z
            ply:SetVelocity(Vector(0, 0, addZ))

            ply.ulxDoubleJumped = true
        elseif ply:IsOnGround() then
            ply.ulxDoubleJumped = false
        end
    end)

    -- Reset double jump on landing
    hook.Add("OnPlayerHitGround", "ULX_ResetDoubleJump", function(ply)
        ply.ulxDoubleJumped = false
    end)
end