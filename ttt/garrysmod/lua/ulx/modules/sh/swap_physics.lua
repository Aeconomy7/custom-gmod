if SERVER then
    function ulx.swap_physics(calling_ply, mode)
        if mode == "bhop" then
            -- Set surf/bhop convars
            RunConsoleCommand("sv_airaccelerate", "600")
            RunConsoleCommand("sv_gravity", "425")
            RunConsoleCommand("sv_maxvelocity", "1250")
            RunConsoleCommand("sv_sticktoground", "0")
            -- RunConsoleCommand("sv_enablebunnyhopping", "1")
            

            for _, ply in ipairs(player.GetAll()) do
                ply:SetNWInt("bhop", 1)
                ply:SetNWInt("doublejump", 0)
            end
            ulx.fancyLogAdmin(calling_ply, "#A set physics mode to BHOP")
        elseif mode == "doublejump" then
            -- Set double jump/low grav convars
            RunConsoleCommand("sv_airaccelerate", "150")
            RunConsoleCommand("sv_gravity", "285")
            RunConsoleCommand("sv_maxvelocity", "3500")
            RunConsoleCommand("sv_sticktoground", "1")
            -- RunConsoleCommand("sv_enablebunnyhopping", "0")
            
            for _, ply in ipairs(player.GetAll()) do
                ply:SetNWInt("bhop", 0)
                ply:SetNWInt("doublejump", 1) 
            end
            ulx.fancyLogAdmin(calling_ply, "#A set physics mode to LOW GRAVITY DOUBLE JUMP")
        else
            ULib.tsayError(calling_ply, "Unknown mode: " .. tostring(mode), true)
        end
    end

    local swap = ulx.command("Fun", "ulx swap_physics", ulx.swap_physics, "!swap_physics")
    swap:addParam{ type=ULib.cmds.StringArg, completes={"bhop", "doublejump"}, hint="mode" }
    swap:defaultAccess(ULib.ACCESS_SUPERADMIN)
    swap:help("Swap between bhop and low gravity double jump modes.")

    -- Ensure double jump is disabled at server start
    hook.Add("Initialize", "ULX_DisableDoubleJumpOnStart", function()
        print("ULX: Disabling double jump on server start")
        for _, ply in ipairs(player.GetAll()) do
            ply:SetNWInt("bhop", 1)
            ply:SetNWInt("doublejump", 0)
        end
    end)
end