if SERVER then AddCSLuaFile() end

roles.InitCustomTeam(ROLE.name, {
    icon  = "vgui/ttt/dynamic/roles/icon_sk",
    color = Color(50, 120, 220, 255),
})

function ROLE:PreInitialize()
    self.color = Color(50, 120, 220, 255)
    self.abbr  = "btm"
    self.icon  = "vgui/ttt/dynamic/roles/icon_sk"

    self.notSelectable = true
    self.isPublicRole  = true
    self.unknownTeam   = false

    self.defaultTeam      = TEAM_BLUETEAM
    self.defaultEquipment = SPECIAL_EQUIPMENT

    self.conVarData = {
        pct          = 0,
        maximum      = 0,
        minPlayers   = 0,
        shopFallback = "blueteam",
        credits      = 0,
    }

    self.score.killsMultiplier     = 2
    self.score.teamKillsMultiplier = -8
end
