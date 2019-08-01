-- Overhaul
function init_globals()
  -- [re]build the list of burner/inserter entities
  global.burner = {}
  for _,surface in pairs(game.surfaces) do
    for _,entity in ipairs(surface.find_entities()) do
      if entity.force.name ~= "neutral" then
        if string.find(entity.name, "burner") and string.find(entity.name, "inserter") then
          local burner = entity
          table.insert(global.burner, burner)
        end
      end
    end
  end
  global.burner_index = 1
  -- [re]build the list of fuel items
  global.fuel_list = {}
  for _, proto in pairs (game.item_prototypes) do
    if proto.fuel_value > 0 then
      table.insert(global.fuel_list,proto.name)
    end
  end
end

script.on_event(defines.events.on_built_entity, function(event)
	if not string.find(event.created_entity.name, "burner") then return end
	if not string.find(event.created_entity.name, "inserter") then return end
  local burner = event.created_entity
  table.insert(global.burner, burner)
  check_burner(burner)
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
	if not string.find(event.created_entity.name, "burner") then return end
	if not string.find(event.created_entity.name, "inserter") then return end
  local burner = event.created_entity
  table.insert(global.burner, burner)
  check_burner(burner)
end)


script.on_event(
    defines.events.on_tick,
    function(event)
        leech()
    end
)

script.on_event(
    defines.events.on_built_entity,
    function(event)
        if not string.find(event.created_entity.name, 'burner') then
            return
        end
        if not string.find(event.created_entity.name, 'inserter') then
            return
        end
        if not global.burner then
            global.burner = {}
        end
        local burner = event.created_entity
        table.insert(global.burner, burner)
        check_burner(burner)
    end
)

script.on_event(
    defines.events.on_robot_built_entity,
    function(event)
        if not string.find(event.created_entity.name, 'burner') then
            return
        end
        if not string.find(event.created_entity.name, 'inserter') then
            return
        end
        log(event.created_entity.name .. ' @ ' .. event.created_entity.position.x .. ', ' .. event.created_entity.position.y)
        if not global.burner then
            global.burner = {}
        end
        local burner = event.created_entity
        table.insert(global.burner, burner)
        check_burner(burner)
    end
)

function leech()
    if not fuel_list then
        --I recalculate the fuel list everytime because adding or removing mod/items can fuck it all up and this doesn't take very long
        fuel_list = {}
        for k, v in pairs(game.item_prototypes) do
            if v.fuel_value > 0 then
                table.insert(fuel_list, v)
            end
        end
    end
    if global.burner_index == nil then
        global.burner_index = 1
    end
    if global.burner == nil then
        return
    end
    if global.burner[global.burner_index] == nil then
        return
    end
    check_burner(global.burner[global.burner_index])
    if global.burner_index >= #global.burner then
        global.burner_index = 1
    else
        global.burner_index = global.burner_index + 1
    end
  if #global.burner == 0 then return end
  if check_burner(global.burner[global.burner_index]) then
    global.burner_index = (global.burner_index % #global.burner) + 1
  end
end

function check_burner(burner)
  if (not burner) or (not burner.valid) then
    table.remove(global.burner, global.burner_index)
    return false
    end
    local surface = burner.surface
    local burners = surface.find_entities_filtered({position = burner.position, force = burner.force, surface = burner.surface})
    if not burners == nil then
        burner = burners[1]
    end
    if not burner.valid then
        table.remove(global.burner, global.burner_index)
        global.burner_index = global.burner_index - 1
        log('return')
        return
    end

    local send_to_target = false
    local take_from_inventory = false
    local pickup_target = {}
    local pt, dt

    if burner.pickup_target == nil then
        pt = surface.find_entities_filtered({position = burner.pickup_position, force = burner.force, surface = burner.surface, limit = 1})
        if pt[1] ~= nil then
            log('pickup_target = ' .. pt[1].name .. ' @ ' .. pt[1].position.x .. ', ' .. pt[1].position.y)
            if pt[1].get_fuel_inventory() ~= nil then
                take_from_inventory = true
                pickup_target = pt[1]
            end
        end
    else
        pickup_target = burner.pickup_target
    end

    -- check self fuel
    -- if > 1 fuel, check drop_position (?)

    if burner.get_fuel_inventory().get_item_count() < 1 then
        burner.drop_target = burner
    else
        dt = surface.find_entities_filtered({position = burner.drop_position, force = burner.force, surface = burner.surface, limit = 1})
        burner.drop_target = dt[1]
    end

    --log(serpent.block(burner.drop_position))

    if burner.drop_target ~= nil then
        if not string.find(burner.drop_target.name, 'burner') then
            return
        end
        log('drop_target = ' .. burner.drop_target.name .. ' @ ' .. burner.drop_target.position.x .. ', ' .. burner.drop_target.position.y)
        if burner.drop_target.get_fuel_inventory() ~= nil then
            if burner.drop_target.get_fuel_inventory().get_item_count() < 1 then
                send_to_target = true
            end
        end
    end

    log(serpent.block(pickup_target))

    if next(pickup_target) == nil then
        return
    end

    log(send_to_target)

    if burner.get_item_count() < 1 or send_to_target then
        leeched = pickup_target
        log(serpent.block(leeched))
        if leeched == nil then
            log('return')
            return
        end
        if burner.held_stack.valid_for_read == false then
            log('valid_for_read = false')
            for j, v in pairs(fuel_list) do
                log(v.name .. ' ' .. leeched.get_item_count(v.name))
                if leeched.get_item_count(v.name) > 0 then
                    burner.held_stack.set_stack({name = v.name, count = 1})
                    leeched.remove_item({name = v.name, count = 1})
                    return
                end
            end
        end
    end
end

script.on_event(defines.events.on_tick, leech)

script.on_init(init_globals)

script.on_configuration_changed(init_globals)