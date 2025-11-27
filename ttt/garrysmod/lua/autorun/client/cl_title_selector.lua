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
        ).internal_id = t.internal_id
    end

    function list:OnRowSelected(_, row)
        local chosen = row.internal_id
        Derma_Query(
            "Equip title '" .. row:GetColumnText(1) .. "'?",
            "Equip Title",
            "Yes",
            function()
                net.Start("sc0b_EquipTitle")
                net.WriteString(chosen)
                net.SendToServer()
            end,
            "Cancel"
        )
    end
end)


concommand.Add("title", function()
    net.Start("sc0b_RequestTitles")
    net.SendToServer()
end)


hook.Add("PlayerSay", "sc0b_TitleChatCommand", function(ply, text)
    text = string.Trim(string.lower(text))

    if text == "!title" or text == "/title" then
        net.Start("sc0b_RequestTitles")
        net.Send(ply)

        return ""
    end
end)