-- Function to simulate a hit with a headshot multiplier
local function applyDamageWithMultiplier(target, baseDamage, multiplier)
    -- Check if the target is a valid player
    if IsValid(target) and target:IsPlayer() then
        -- Get the head bone index
        local headBone = target:LookupBone("ValveBiped.Bip01_Head1")
        if headBone then
            -- Get the position of the head bone
            local headPos, headAng = target:GetBonePosition(headBone)
            
            -- Calculate damage based on head hit detection
            local dmgAmount = baseDamage
            local hitPos = target:GetEyeTrace().HitPos  -- Simulates hit detection

            if hitPos:Distance(headPos) < 5 then  -- Check if hit is close to head bone position
                dmgAmount = baseDamage * multiplier
                print("Headshot detected! Damage applied:", dmgAmount)
            else
                print("Body shot. Normal damage applied:", baseDamage)
            end

            -- Create and apply damage
            local dmgInfo = DamageInfo()
            dmgInfo:SetDamage(dmgAmount)
            dmgInfo:SetDamageType(DMG_BULLET)
            dmgInfo:SetAttacker(target)
            dmgInfo:SetDamagePosition(hitPos)

            target:TakeDamageInfo(dmgInfo)
        else
            print("Head bone not found for this model.")
        end
    end
end

-- Example usage: Apply damage with a multiplier for headshots
concommand.Add("simulate_hit_with_multiplier", function(ply, cmd, args)
    local target = ply  -- Targets the player who entered the command
    local baseDamage = tonumber(args[1]) or 50  -- Base damage
    local multiplier = tonumber(args[2]) or 2.0  -- Headshot damage multiplier (e.g., 2x)
    applyDamageWithMultiplier(target, baseDamage, multiplier)
end)

