include("autorun/client/cl_darkstyle.lua")

net.Receive("OpenTrailMenu", function()
    local trails = net.ReadTable()

    local frame = vgui.Create("DFrame")
    ApplyDarkTheme(frame) -- Apply dark theme to the frame
    frame:SetTitle("Choose Your Trail")
    frame:SetSize(600, 700)
    frame:Center()
    frame:MakePopup()

    local modifiersPanel = vgui.Create("DPanel", frame)
    modifiersPanel:Dock(TOP)
    modifiersPanel:SetTall(260)
    modifiersPanel:DockPadding(10, 10, 10, 10)

    ApplyDarkTheme(modifiersPanel) -- Apply dark theme to the modifiers panel

    local mixer = vgui.Create("DColorMixer", modifiersPanel)
    mixer:SetSize(200, 160)
    mixer:SetPos(10, 10)
    mixer:SetPalette(true)
    mixer:SetAlphaBar(false)
    mixer:SetWangs(true)
    mixer:SetColor(Color(255, 255, 255))
    
    ApplyDarkTheme(mixer) -- Apply dark theme to the color mixer

    local startSizeSlider = vgui.Create("DNumSlider", modifiersPanel)
    startSizeSlider:SetText("Start Size")
    startSizeSlider:SetDark(true)
    startSizeSlider:SetMinMax(0, 64)
    startSizeSlider:SetDecimals(0)
    startSizeSlider:SetValue(16)
    startSizeSlider:SetPos(230, 10)
    startSizeSlider:SetSize(340, 30)

    ApplyDarkTheme(startSizeSlider) -- Apply dark theme to the start size slider

    local endSizeSlider = vgui.Create("DNumSlider", modifiersPanel)
    endSizeSlider:SetText("End Size")
    endSizeSlider:SetDark(true)
    endSizeSlider:SetMinMax(0, 64)
    endSizeSlider:SetDecimals(0)
    endSizeSlider:SetValue(16)
    endSizeSlider:SetPos(230, 50)
    endSizeSlider:SetSize(340, 30)

    ApplyDarkTheme(endSizeSlider) -- Apply dark theme to the end size slider

    local trailLenSlider = vgui.Create("DNumSlider", modifiersPanel)
    trailLenSlider:SetText("Trail Length")
    trailLenSlider:SetDark(true)
    trailLenSlider:SetMinMax(1, 100)
    trailLenSlider:SetDecimals(0)
    trailLenSlider:SetValue(15)
    trailLenSlider:SetPos(230, 90)
    trailLenSlider:SetSize(340, 30)

    ApplyDarkTheme(trailLenSlider) -- Apply dark theme to the trail length slider

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(10, 0, 10, 10)

    ApplyDarkTheme(scroll) -- Apply dark theme to the scroll panel

    local layout = vgui.Create("DIconLayout", scroll)
    layout:Dock(TOP)
    layout:SetSpaceY(10)
    layout:SetSpaceX(10)
    layout:SetSize(560, 400)

    for _, trail in ipairs(trails) do
        local icon = layout:Add("DButton")
        icon:SetSize(128, 128)
        icon:SetText("")

        if trail.material == "none" then
            icon.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, Color(50, 50, 50))
                draw.SimpleText("No Trail", "DermaDefaultBold", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        else
            local mat = Material(trail.material)
            icon.Paint = function(self, w, h)
                surface.SetDrawColor(255, 255, 255)
                surface.SetMaterial(mat)
                surface.DrawTexturedRect(0, 0, w, h)
                draw.SimpleText(trail.name, "DermaDefaultBold", w / 2, h - 12, color_white, TEXT_ALIGN_CENTER)
            end
        end

        icon.DoClick = function()
            local col = mixer:GetColor()
            local startSize = math.floor(startSizeSlider:GetValue())
            local endSize = math.floor(endSizeSlider:GetValue())
            local length = math.floor(trailLenSlider:GetValue())

            net.Start("SelectTrail")
                net.WriteString(trail.material)
                net.WriteUInt(col.r, 8)
                net.WriteUInt(col.g, 8)
                net.WriteUInt(col.b, 8)
                net.WriteUInt(startSize, 8)
                net.WriteUInt(endSize, 8)
                net.WriteUInt(length, 8)
            net.SendToServer()

            frame:Close()
        end
    end

    
    ApplyDarkTheme(layout) -- Apply dark theme to the icon layout
end)