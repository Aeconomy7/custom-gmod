print("[DarkUI] Loaded dark style utilities")

function ApplyDarkTheme(panel)
    if not IsValid(panel) then return end

    local class = panel:GetClassName()

    if class == "DFrame" then
        panel.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30))
            draw.SimpleText(self:GetTitle(), "DermaLarge", 10, 8, color_white, TEXT_ALIGN_LEFT)
        end
        panel:SetTitle("")
    elseif class == "DNumSlider" then
        panel.Label:SetTextColor(color_white)
        panel.Scratch:SetPaintBackgroundEnabled(false)
        panel.Scratch:SetTextColor(color_white)
        panel.Scratch.Paint = function(_, w, h)
            surface.SetDrawColor(20, 20, 20)
            surface.DrawRect(0, 0, w, h)
        end
        panel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 20))
        end
    elseif class == "DColorMixer" then
        panel:SetPalette(true)
        panel:SetAlphaBar(false)
        panel:SetWangs(true)
    elseif class == "DScrollPanel" then
        panel.Paint = function(self, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Color(30, 30, 30))
        end
    elseif class == "DButton" then
        panel:SetTextColor(color_white)
        panel.Paint = function(self, w, h)
            if self:IsHovered() then
                draw.RoundedBox(4, 0, 0, w, h, Color(64, 128, 255))
            else
                draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 20))
            end
            draw.SimpleText(self:GetText(), "DermaDefaultBold", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end