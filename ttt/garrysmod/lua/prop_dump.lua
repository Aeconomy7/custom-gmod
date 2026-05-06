local lines = {}
for _, e in ipairs(ents.GetAll()) do
    local c = e:GetClass()
    if string.find(c, "prop") or string.find(c, "func_phys") then
        lines[#lines+1] = c .. "," .. tostring(e:Health()) .. "," .. tostring(e:GetModel())
    end
end
file.Write("prop_dump.txt", table.concat(lines, "\n"))
print("[prop_dump] Written " .. #lines .. " entries to data/prop_dump.txt")
