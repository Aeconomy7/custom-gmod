if not ulx then return end
if not SERVER then return end

-- Load all achievements from SQL
local function GetAllAchievements()
    local rows = sql.Query("SELECT internal_id, name FROM all_achievements ORDER BY name ASC")
    return rows or {}
end

---------------------------
-- ULX COMMAND: Grant Achievement
---------------------------
function ulx.grantachievement(calling_ply, target_ply, internal_id)
    if not IsValid(target_ply) then
        ULib.tsayError(calling_ply, "Invalid target player!")
        return
    end

    if not internal_id or internal_id == "" then
        ULib.tsayError(calling_ply, "Invalid achievement ID!")
        return
    end

    sc0b_GrantAchievementByInternalID(target_ply, internal_id)

    ulx.fancyLogAdmin(calling_ply, "#A granted achievement #s to #T", internal_id, target_ply)
end

local cmd = ulx.command("Custom Achievements", "ulx grantachievement", ulx.grantachievement, "!grantachievement")
cmd:addParam{ type = ULib.cmds.PlayerArg }
cmd:addParam{ type = ULib.cmds.StringArg, hint = "achievement internal_id" }
cmd:defaultAccess(ULib.ACCESS_ADMIN)
cmd:help("Grant a custom achievement to a player.")

-- Send achievements list to clients for ULX menu
util.AddNetworkString("sc0b_ULX_AchievementList")

hook.Add("PlayerInitialSpawn", "sc0b_ULX_SendAchievements", function(ply)
    timer.Simple(3, function()
        if not IsValid(ply) then return end

        local ach = GetAllAchievements()

        net.Start("sc0b_ULX_AchievementList")
        net.WriteTable(ach)
        net.Send(ply)
    end)
end)