for _, v in pairs(data.raw.inserter) do
    if settings.startup['bl-allow-non-burners-to-leech'].value == true then
        -- allow ALL inserters to leech
        v.allow_burner_leech = true
    elseif v.energy_source.type == "burner" then
        v.allow_burner_leech = true
    end
end
