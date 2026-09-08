-- TTT2's DecalRemovable passes a filter table containing entity references. If those
-- entities were removed server-side before the net message arrives, net.ReadTable()
-- deserialises them as false. util.Decal then errors: "expecting entity, got boolean".
-- Patch the function to strip invalid entries from the filter before calling through.
if not CLIENT then return end

-- Defer so sh_decal.lua (gamemode shared file) has already defined util.DecalRemovable.
timer.Simple(0, function()
    local _orig = util.DecalRemovable
    if not isfunction(_orig) then return end

    function util.DecalRemovable(id, name, startpos, endpos, filter)
        if filter == false or filter == true then
            filter = nil
        elseif istable(filter) then
            local clean = {}
            for _, v in ipairs(filter) do
                if IsValid(v) then clean[#clean + 1] = v end
            end
            filter = #clean > 0 and clean or nil
        end
        return _orig(id, name, startpos, endpos, filter)
    end
end)
