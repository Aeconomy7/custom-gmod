if SERVER then AddCSLuaFile() end

roles.InitCustomTeam(ROLE.name, {
    icon  = "vgui/ttt/dynamic/roles/icon_hit",
    color = Color(255, 215, 0, 255),
})

function ROLE:PreInitialize()
    self.color = Color(255, 215, 0, 255)
    self.abbr  = "ffa"
    self.icon  = "vgui/ttt/dynamic/roles/icon_hit"

    self.notSelectable = true
    self.isPublicRole  = false
    self.unknownTeam   = true

    self.defaultTeam      = TEAM_FFA
    self.defaultEquipment = SPECIAL_EQUIPMENT

    self.conVarData = {
        pct          = 0,
        maximum      = 0,
        minPlayers   = 0,
        shopFallback = SHOP_DISABLED,
        credits      = 0,
    }

    -- In FFA every kill is a same-team kill; use a positive multiplier so kills reward score
    self.score.killsMultiplier     = 2
    self.score.teamKillsMultiplier = 2
end
