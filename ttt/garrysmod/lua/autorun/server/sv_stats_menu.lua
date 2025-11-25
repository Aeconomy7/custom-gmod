-- sv_stats.lua
util.AddNetworkString("sc0b_SendStats")

-- Trigger from chat
hook.Add("PlayerSay", "sc0b_StatsCommand", function(ply, text)
    print("[STATS MENU] Sending stats to " .. ply:Nick())
    sc0b_GrantAchievementByInternalID(ply, "open_stats_menu")
    if string.lower(text) == "!mystats" then
        net.Start("sc0b_SendStats")
        net.Send(ply)
        return ""
    end
end)

-- Trigger from console
concommand.Add("sc0b_mystats", function(ply)
    print("[STATS MENU] Sending stats to " .. ply:Nick())
    sc0b_GrantAchievementByInternalID(ply, "open_stats_menu")
    net.Start("sc0b_SendStats")
    net.WriteTable(GetPlayerStats(ply:SteamID64()))
    net.Send(ply)
end)

