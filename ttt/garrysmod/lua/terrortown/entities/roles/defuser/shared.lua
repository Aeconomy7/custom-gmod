if SERVER then AddCSLuaFile() end

roles.InitCustomTeam(ROLE.name, {
    icon  = "vgui/ttt/dynamic/roles/icon_hit",
    color = Color(30, 120, 220, 255),
})

function ROLE:PreInitialize()
    self.color = Color(30, 120, 220, 255)
    self.abbr  = "dfs"
    self.icon  = "vgui/ttt/dynamic/roles/icon_hit"

    self.notSelectable = true
    self.isPublicRole  = true
    self.unknownTeam   = false

    self.defaultTeam      = TEAM_DEFUSER
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
