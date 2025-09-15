-- cl_stats.lua
surface.CreateFont("BudgetLabel12", {
    font = "BudgetLabel",
    size = 12,
    weight = 600,
    antialias = true,
    extended = true
})

surface.CreateFont("Impact18", {
    font = "Impact",
    size = 18,
    weight = 600,
    antialias = true,
    extended = true
})

-- Receive TTT stats
net.Receive("sc0b_SendStats", function()
    local stats = net.ReadTable()
    local totalRounds = stats.total > 0 and stats.total or 1

    local frame = vgui.Create("DFrame")
    frame:SetTitle("TRT TTT2 Stats")
    frame:SetSize(700, 700)
    frame:Center()
    frame:MakePopup()

    -- Use a property sheet (tabs)
    local tabs = vgui.Create("DPropertySheet", frame)
    tabs:Dock(FILL)
    tabs:DockMargin(10, 30, 10, 10)

    -- =====================
    -- Stats Tab
    -- =====================
    local statsPanel = vgui.Create("DScrollPanel", tabs)
    tabs:AddSheet("Stats", statsPanel, "icon16/chart_bar.png")

    local roles = {
        {name = "innocents",       count = stats.innocents,       wins = stats.innocents_wins,       color = Color(80, 220, 120)},
        {name = "traitors",        count = stats.traitors,        wins = stats.traitors_wins,        color = Color(200, 60, 60)},
        {name = "serialkillers",   count = stats.serialkillers,   wins = stats.serialkillers_wins,   color = Color(30, 150, 160)},
        {name = "necromancers",    count = stats.necromancers,    wins = stats.necromancers_wins,    color = Color(120, 70, 160)},
        {name = "jesters",         count = stats.jesters,         wins = stats.jesters_wins,         color = Color(190, 90, 230)},
        {name = "markers",         count = stats.markers,         wins = stats.markers_wins,         color = Color(180, 100, 255)}
    }

    local rowHeight = 60
    local padding = 10

    for _, role in ipairs(roles) do
        local pctPlayed = role.count / totalRounds
        local pctWin = role.count > 0 and (role.wins / role.count) or 0

        local barPanel = vgui.Create("DPanel", statsPanel)
        barPanel:SetSize(440, rowHeight)
        barPanel:Dock(TOP)
        barPanel:DockMargin(0, 0, 0, padding)
        barPanel.Paint = function(self, w, h)
            surface.SetDrawColor(40, 40, 40, 200)
            surface.DrawRect(0, 0, w, h)

            -- Played percentage bar
            surface.SetDrawColor(role.color)
            surface.DrawRect(0, 0, w * pctPlayed, h / 2)

            -- Win rate bar
            surface.SetDrawColor(Color(255, 215, 0))
            surface.DrawRect(0, h / 2, w * pctWin, h / 2)

            draw.SimpleText(string.format("%s: %d rounds (%.1f%%) / Wins: %d (%.1f%%)",
                role.name, role.count, pctPlayed * 100,
                role.wins, pctWin * 100),
                "BudgetLabel12", 10, h / 4, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    -- Summary
    local summary = vgui.Create("DPanel", statsPanel)
    summary:SetTall(60)
    summary:Dock(TOP)
    summary:DockMargin(0, 10, 0, 0)
    summary.Paint = function(self, w, h)
        surface.SetDrawColor(60, 60, 60, 200)
        surface.DrawRect(0, 0, w, h)

        draw.SimpleText("Total Rounds: " .. stats.total, "BudgetLabel12", 10, 15, color_white, TEXT_ALIGN_LEFT)
        draw.SimpleText("Total Wins: " .. stats.wins_total, "BudgetLabel12", w - 10, 15, Color(255, 215, 0), TEXT_ALIGN_RIGHT)

        -- Draw stacked bar for total rounds
        local xOffset = 0
        for _, role in ipairs(roles) do
            if role.count > 0 then
                local barWidth = (role.count / totalRounds) * w
                surface.SetDrawColor(role.color)
                surface.DrawRect(xOffset, h - 20, barWidth, 15)
                xOffset = xOffset + barWidth
            end
        end

        -- Optional border around bar
        surface.SetDrawColor(255, 255, 255, 100)
        surface.DrawOutlinedRect(0, h - 20, w, 15)
    end

    -- =====================
    -- Rank Tab
    -- =====================
    local rankPanel = vgui.Create("DScrollPanel", tabs)
    tabs:AddSheet("Rank", rankPanel, "icon16/star.png")

    -- Request rank info from server
    RunConsoleCommand("sc0b_request_xp")

    timer.Simple(0.1, function()
        local ply = LocalPlayer()
        local level = ply:GetNWInt("level", 1)
        local xp = ply:GetNWInt("xp", 0)
        local total_xp = ply:GetNWInt("total_xp", 0)

        -- Calculate XP bounds for current level
        local minXP = 20 * (level - 1)^2
        local maxXP = 20 * level^2
        local progress = math.Clamp((xp - minXP) / (maxXP - minXP), 0, 1)

        -- Rainbow color for progress
        local hue = progress * 360
        local barColor = HSVToColor(hue, 1, 1)

        local rankBar = vgui.Create("DPanel", rankPanel)
        rankBar:SetSize(440, 60)
        rankBar:Dock(TOP)
        rankBar:DockMargin(0, 0, 0, 10)
        rankBar.Paint = function(self, w, h)
            surface.SetDrawColor(40, 40, 40, 200)
            surface.DrawRect(0, 0, w, h)

            -- XP progress bar (rainbow)
            surface.SetDrawColor(barColor.r, barColor.g, barColor.b, 255)
            surface.DrawRect(0, h / 2, w * progress, h / 2)

            -- Border
            surface.SetDrawColor(255, 255, 255, 80)
            surface.DrawOutlinedRect(0, h / 2, w, h / 2)

            -- Level label
            draw.SimpleText(string.format("Level %d %s", level, (level >= 20 and "🌟" or level >= 10 and "✨" or "•")),
                "BudgetLabel12", 10, 5, color_white, TEXT_ALIGN_LEFT)
            -- XP label
            draw.SimpleText(string.format("XP: %d / %d", xp - minXP, maxXP - minXP),
                "BudgetLabel12", 10, h / 2 + 5, color_white, TEXT_ALIGN_LEFT)
            -- Total XP label
            draw.SimpleText(string.format("Total XP: %d", total_xp),
                "BudgetLabel12", w - 10, h / 2 + 5, Color(255, 215, 0), TEXT_ALIGN_RIGHT)
        end
    end)

    -- =====================
    -- Kill Stats Tab
    -- =====================
    local killPanel = vgui.Create("DScrollPanel", tabs)
    tabs:AddSheet("Kills", killPanel, "icon16/user.png")

    local playerKills = stats.kills or 0
    local playerDeaths = stats.deaths or 0
    local killLog = stats.killlog or {} -- table of {time, killer, killer_role, victim, victim_role, weapon}

    -- Top summary panel
    local summaryPanel = vgui.Create("DPanel", killPanel)
    summaryPanel:SetTall(60)
    summaryPanel:Dock(TOP)
    summaryPanel:DockMargin(0,0,0,10)
    summaryPanel.Paint = function(self,w,h)
        surface.SetDrawColor(60,60,60,200)
        surface.DrawRect(0,0,w,h)

        draw.SimpleText("Total Kills: "..playerKills, "BudgetLabel12", 10, 10, Color(80,220,120), TEXT_ALIGN_LEFT)
        draw.SimpleText("Total Deaths: "..playerDeaths, "BudgetLabel12", 10, 30, Color(238,75,43), TEXT_ALIGN_LEFT)
        draw.SimpleText("K/D Ratio: "..(playerDeaths>0 and string.format("%.2f",playerKills/playerDeaths) or "N/A"), "BudgetLabel12", w-10, 10, color_white, TEXT_ALIGN_RIGHT)
        draw.SimpleText("Last 20 Involved Kills", "BudgetLabel12", w-10, 30, color_white, TEXT_ALIGN_RIGHT)
    end

    -- Kill log entries
    for i=#killLog,1,-1 do
        local entry = killLog[i]
        if not entry then continue end

        local isKill = entry.killer_nick == LocalPlayer():Nick()
        local isDeath = entry.victim_nick == LocalPlayer():Nick()

        local entryPanel = vgui.Create("DPanel", killPanel)
        entryPanel:SetTall(40)
        entryPanel:Dock(TOP)
        entryPanel:DockMargin(0,0,0,5)
        entryPanel.Paint = function(self,w,h)
            surface.SetDrawColor(50,50,50,180)
            surface.DrawRect(0,0,w,h)

            local col = isKill and Color(80,220,120) or (isDeath and Color(238,75,43) or color_white)

            local text
            if isKill then
                text = string.format("[%s] You (%s) killed %s (%s) with %s",
                    os.date("%H:%M:%S",entry.time),
                    entry.killer_role,
                    entry.victim_nick, entry.victim_role,
                    entry.weapon)
            elseif isDeath then
                text = string.format("[%s] You (%s) were killed by %s (%s) with %s",
                    os.date("%H:%M:%S",entry.time),
                    entry.killer_role, entry.killer_nick, entry.killer_role,
                    entry.weapon)
            else
                text = string.format("[%s] %s (%s) → %s (%s) | %s",
                    os.date("%H:%M:%S",entry.time),
                    entry.killer_nick, entry.killer_role,
                    entry.victim_nick, entry.victim_role,
                    entry.weapon)
            end

            draw.SimpleText(text, "BudgetLabel12", 10, h/2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end


    -- =====================
    -- Leaderboard Tab
    -- =====================
    -- local leaderboardPanel = vgui.Create("DPropertySheet", tabs)
    -- tabs:AddSheet("Leaderboard", leaderboardPanel, "icon16/trophy.png")

    -- -- Panels for each leaderboard type
    -- local overallPanel = vgui.Create("DScrollPanel", leaderboardPanel)
    -- leaderboardPanel:AddSheet("Overall", overallPanel, "icon16/medal_gold_1.png")

    -- local dailyPanel = vgui.Create("DScrollPanel", leaderboardPanel)
    -- leaderboardPanel:AddSheet("Today", dailyPanel, "icon16/calendar.png")

    -- local rolesPanel = vgui.Create("DScrollPanel", leaderboardPanel)
    -- leaderboardPanel:AddSheet("By Role", rolesPanel, "icon16/group.png")

    -- -- Request leaderboard data
    -- net.Start("sc0b_RequestLeaderboard")
    -- net.SendToServer()

    -- net.Receive("sc0b_SendLeaderboard", function()
    --     local data = net.ReadTable()

    --     local function Populate(panel, tbl, titleFn)
    --         panel:Clear()
    --         for i, row in ipairs(tbl) do
    --             local entry = vgui.Create("DPanel", panel)
    --             entry:SetTall(30)
    --             entry:Dock(TOP)
    --             entry:DockMargin(0,0,0,5)
    --             entry.Paint = function(self,w,h)
    --                 surface.SetDrawColor(50,50,50,200)
    --                 surface.DrawRect(0,0,w,h)
    --                 draw.SimpleText(titleFn(i, row), "BudgetLabel12", 10, h/2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    --             end
    --         end
    --     end

    --     -- Fill each panel
    --     Populate(overallPanel, data.overall, function(i,row)
    --         return string.format("#%d %s - %s kills", i, row.killer or "Unknown", row.kills)
    --     end)

    --     Populate(dailyPanel, data.daily, function(i,row)
    --         return string.format("#%d %s - %s kills today", i, row.killer or "Unknown", row.kills)
    --     end)

    --     Populate(rolesPanel, data.roles, function(i,row)
    --         return string.format("#%d [%s] %s - %s kills", i, row.killer_role or "?", row.killer or "Unknown", row.kills)
    --     end)
    -- end)
end)
