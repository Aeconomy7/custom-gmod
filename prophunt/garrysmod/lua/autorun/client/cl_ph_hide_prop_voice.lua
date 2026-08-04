-- cl_ph_hide_prop_voice.lua
-- Suppresses the engine voice sprite above alive prop players.
-- We create a VMT wrapper for voice/icntlk_sv so its $alpha can be
-- manipulated at runtime. When any alive prop is speaking the sprite
-- is made fully transparent; otherwise it renders normally.
if not CLIENT then return end
if engine.ActiveGamemode() ~= "prop_hunt" then return end

local voiceMat = Material("voice/icntlk_sv")

hook.Add("PreRender", "PHX_HidePropVoiceSprite", function()
    if voiceMat:IsError() then return end

    local propSpeaking = false
    for _, ply in ipairs(player.GetAll()) do
        if ply:IsSpeaking() and ply:Alive() and ply:Team() == TEAM_PROPS then
            propSpeaking = true
            break
        end
    end

    voiceMat:SetFloat("$alpha", propSpeaking and 0.0 or 1.0)
end)
