if SERVER then AddCSLuaFile() end

roles.InitCustomTeam(ROLE.name, {
    icon  = "vgui/ttt/dynamic/roles/icon_mark",
    color = Color(220, 80, 30, 255),
})

function ROLE:PreInitialize()
    self.color = Color(220, 80, 30, 255)
    self.abbr  = "plt"
    self.icon  = "vgui/ttt/dynamic/roles/icon_mark"

    self.notSelectable = true
    self.isPublicRole  = true
    self.unknownTeam   = false

    self.defaultTeam      = TEAM_PLANTER
    self.defaultEquipment = SPECIAL_EQUIPMENT

    self.conVarData = {
        pct          = 0,
        maximum      = 0,
        minPlayers   = 0,
        shopFallback = SHOP_DISABLED,
        credits      = 0,
    }

    self.score.killsMultiplier     = 2
    self.score.teamKillsMultiplier = -8
end
