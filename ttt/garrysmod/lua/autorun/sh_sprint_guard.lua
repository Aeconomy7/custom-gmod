-- Guard against GetSprintStamina being nil on uninitialized players.
-- TTT2 calls SPRINT:HandleStaminaCalculation in GM:FinishMove, which can
-- fire before a player's sprint NWVars are fully set up (e.g. on connect).

local function PatchSprint()
    if not SPRINT or not SPRINT.HandleStaminaCalculation then return end

    local orig = SPRINT.HandleStaminaCalculation
    SPRINT.HandleStaminaCalculation = function(self, ply)
        if not IsValid(ply) or not ply.GetSprintStamina then return end
        return orig(self, ply)
    end
end

-- SERVER: runs after gamemode Initialize
-- CLIENT: InitPostEntity fires after all entities (including localplayer) exist
if SERVER then
    hook.Add("Initialize", "GS_SprintGuard", PatchSprint)
else
    hook.Add("InitPostEntity", "GS_SprintGuard", PatchSprint)
end
