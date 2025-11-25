if SERVER then return end

net.Receive("sc0b_SendTitles", function()
    local titles = net.ReadTable()

    local frame = vgui.Create("DFrame")
    frame:SetSize(400, 500)
    frame:Center()
    frame:SetTitle("Choose Achievement Title")
    frame:MakePopup()

    local list = vgui.Create("DListView", frame)
    list:Dock(FILL)
    list:AddColumn("Title")
    list:AddColumn("Equipped")

    for _, t in ipairs(titles) do
        list:AddLine(
            t.name,
            t.equipped == 1 and "YES" or "NO"
        ).ach_id = t.ach_id
    end

    function list:OnRowSelected(_, row)
        local chosen = row.ach_id
        Derma_Query(
            "Equip title '" .. row:GetColumnText(1) .. "'?",
            "Equip Title",
            "Yes",
            function()
                net.Start("sc0b_EquipTitle")
                net.WriteInt(chosen, 32)
                net.SendToServer()
            end,
            "Cancel"
        )
    end
end)

-- Open UI (bind this to F4 or a menu button)
concommand.Add("title", function()
    net.Start("sc0b_RequestTitles")
    net.SendToServer()
end)
