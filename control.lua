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

function leech()
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
  local send_to_target = false
  if burner.drop_target ~= nil then
    if burner.drop_target.get_fuel_inventory() ~= nil then
      if burner.drop_target.get_fuel_inventory().get_item_count() < 1 then
        send_to_target = true
      end
    end
  end
  if burner.pickup_target == nil then return true end
  if burner.get_item_count() < 1 or send_to_target then
    leeched = burner.pickup_target
    if leeched == nil then return end
    if burner.held_stack.valid_for_read == false then
      for _, fuel in pairs (global.fuel_list) do
        if leeched.get_item_count(fuel) > 0 then
          burner.held_stack.set_stack({name = fuel, count = 1})
          leeched.remove_item({name = fuel, count = 1})
          return true
        end
      end
    end
  end
  return true
end

script.on_event(defines.events.on_tick, leech)

script.on_init(init_globals)

script.on_configuration_changed(init_globals)