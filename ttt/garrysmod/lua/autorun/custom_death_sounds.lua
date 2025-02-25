if SERVER then
	local deathSounds = {}

	AddCSLuaFile()


	local mp3Files = file.Find("sound/death_sounds/*.mp3", "GAME")
	local wavFiles = file.Find("sound/death_sounds/*.wav", "GAME")


	for _, fileName in ipairs(mp3Files) do
		table.insert(deathSounds, "death_sounds/" .. fileName)
	end

	for _, fileName in ipairs(wavFiles) do
		table.insert(deathSounds, "death_sounds/" .. fileName)
	end


	for _, soundPath in ipairs(deathSounds) do
		resource.AddFile("sound/" .. soundPath)
		print("[Custom Death Sounds] AddFile: " .. soundPath)
	end


	hook.Add("PlayerDeath", "CustomDeathSound", function(victim, inflictor, attacker)
		if not IsValid(victim) then
			return
		end

		deathSound = deathSounds[math.random(#deathSounds)]

		print("[Custom Death Sounds] Playing " .. deathSound)
		victim:EmitSound(deathSound)
    end)
end
