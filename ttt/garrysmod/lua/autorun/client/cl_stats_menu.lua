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

surface.CreateFont("Impact24", {
    font = "Impact",
    size = 24,
    weight = 600,
    antialias = true,
    extended = true
})

surface.CreateFont("Impact32", {
    font = "Impact",
    size = 32,
    weight = 600,
    antialias = true,
    extended = true
})

surface.CreateFont("Impact36", {
    font = "Impact",
    size = 36,
    weight = 600,
    antialias = true,
    extended = true
})

-- Receive TTT stats
net.Receive("sc0b_SendStats", function()
    local frame = vgui.Create("DFrame")
    frame:SetTitle("Great Sea TTT2 Stats")
    frame:SetSize(1200, 800)
    frame:Center()
    frame:MakePopup()

    -- Use a property sheet (tabs)
    local tabs = vgui.Create("DPropertySheet", frame)
    tabs:Dock(FILL)
    tabs:DockMargin(10, 30, 10, 10)

   -- Profile tab (already present)
    local steamid = LocalPlayer():SteamID64()
    local profilePanel = vgui.Create("DPanel", tabs)
    profilePanel:Dock(FILL)

    local html = vgui.Create("DHTML", profilePanel)
    html:Dock(FILL)
    html:OpenURL("https://greatsea.online/player/" .. steamid)

    tabs:AddSheet("My Profile", profilePanel, "icon16/user.png")

    -- Round Report tab
    local reportPanel = vgui.Create("DPanel", tabs)
    reportPanel:Dock(FILL)

    local reportHtml = vgui.Create("DHTML", reportPanel)
    reportHtml:Dock(FILL)
    reportHtml:OpenURL("https://greatsea.online/ttt_round_report/")

    tabs:AddSheet("Round Report", reportPanel, "icon16/report.png")

    -- Round Report tab
    local reportPanel = vgui.Create("DPanel", tabs)
    reportPanel:Dock(FILL)

    local reportHtml = vgui.Create("DHTML", reportPanel)
    reportHtml:Dock(FILL)
    reportHtml:OpenURL("https://greatsea.online/ttt_leaderboards/")

    tabs:AddSheet("Leaderboards", reportPanel, "icon16/medal_gold_1.png")

    -- Round Report tab
    local reportPanel = vgui.Create("DPanel", tabs)
    reportPanel:Dock(FILL)

    local reportHtml = vgui.Create("DHTML", reportPanel)
    reportHtml:Dock(FILL)
    reportHtml:OpenURL("https://greatsea.online/ttt_guide/")

    tabs:AddSheet("How to Play", reportPanel, "icon16/help.png")
end)


