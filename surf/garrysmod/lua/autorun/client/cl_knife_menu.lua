include("autorun/client/cl_darkstyle.lua")

net.Receive("OpenKnifeMenu", function()
    local skins = net.ReadTable()

    local frame = vgui.Create("DFrame")
    frame:SetTitle("Choose Your Knife")
    frame:SetSize(600, 400)
    frame:Center()
    frame:MakePopup()

    ApplyDarkTheme(frame) -- Apply dark theme to the frame

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)

    ApplyDarkTheme(scroll) -- Apply dark theme to the scroll panel

    local layout = vgui.Create("DIconLayout", scroll)
    layout:Dock(FILL)
    layout:SetSpaceY(10)
    layout:SetSpaceX(10)

    for _, skin in ipairs(skins) do
        local mat = Material(skin.icon, "smooth mips")

        local icon = layout:Add("DButton")
        icon:SetSize(128, 128)
        icon:SetText("")

        icon.Paint = function(self, w, h)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(mat)
            surface.DrawTexturedRect(0, 0, w, h)
            draw.SimpleText(skin.name, "DermaDefaultBold", w / 2, h - 16, color_white, TEXT_ALIGN_CENTER)
        end

        icon.DoClick = function()
            net.Start("SelectKnifeSkin")
            net.WriteString(skin.class)
            net.SendToServer()
            frame:Close()
        end
    end

    ApplyDarkTheme(layout) -- Apply dark theme to the icon layout
end)