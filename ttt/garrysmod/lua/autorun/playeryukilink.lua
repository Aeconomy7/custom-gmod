player_manager.AddValidModel( "Link","models/player_link.mdl" )
player_manager.AddValidModel( "Linkweapons","models/player_linkweapons.mdl" )
player_manager.AddValidHands( "Link", "models/link_viewarms.mdl", 0, "00000000" )
player_manager.AddValidHands( "Linkweapons", "models/link_viewarms.mdl", 0, "00000000" )

list.Set( "PlayerOptionsModel",  "Link","models/player_link.mdl" )
list.Set( "PlayerOptionsModel",  "Link","models/player_linkweapons.mdl" )

--Add NPC
local Category = "Link NPC"

local NPCA = {
	Name = "Link",
	Class = "npc_citizen",
	Model = "Models/npc_link.mdl",
	Health = "100",
	KeyValues = { citizentype = 4 },
	Category = Category
}
local NPCB = {
	Name = "Link Weapons",
	Class = "npc_citizen",
	Model = "Models/npc_linkweapons.mdl",
	Health = "100",
	KeyValues = { citizentype = 4 },
	Category = Category
}

list.Set( "NPC", "npc_link", NPCA )
list.Set( "NPC", "npc_link_weapons", NPCB )
