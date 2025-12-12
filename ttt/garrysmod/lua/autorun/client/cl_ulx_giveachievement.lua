local achievement_list = {}

net.Receive("sc0b_ULX_AchievementList", function()
    achievement_list = net.ReadTable() or {}
end)

-----------------------------------------
-- ULX MENU CREATION
-----------------------------------------
function ulx.populateAchievePanel(panel)
    panel:Clear()

    panel:AddControl("Header", { text = "Grant Player Achievement" })

    local plySelect = panel:AddControl("ComboBox", {
        Label = "Select Player",
        MenuButton = 0
    })

    for _, ply in ipairs(player.GetAll()) do
        plySelect:AddChoice(ply:Nick(), ply)
    end

    local achSelect = panel:AddControl("ComboBox", {
        Label = "Select Achievement",
        MenuButton = 0
    })

    for _, row in ipairs(achievement_list) do
        achSelect:AddChoice(row.name .. " (" .. row.internal_id .. ")", row.internal_id)
    end

    panel:Button("Grant Achievement", "ulx grantachievement", {
        ulxPlayer = plySelect,
        ulxStringArg = achSelect
    })
end

hook.Add("ULXPopulateCustomAchieve", "AddCustomAchievementPanel", function()
    ulx.addToCategory("Custom Achievements", "Grant Achievements", ulx.populateAchievePanel, "icon16/star.png")
end)