require "stdlib/string"
require "stdlib/area/position"


replaceCarriage = require("__Robot256Lib__/script/carriage_replacement").replaceCarriage
blueprintLib = require("__Robot256Lib__/script/blueprint_replacement")
saveRestoreLib = require("__Robot256Lib__/script/save_restore")

script.on_init(function() On_Init() end)
script.on_configuration_changed(function() On_Init() end)
script.on_load(function() On_Load() end)


-- Go through all the available prototypes and assign them to a valid loaded wagon or "nope"
function InitializeTypeMapping()
  global.vehicleMap = {}
  for k,_ in pairs(game.get_filtered_entity_prototypes({{filter="type", type="car"}})) do
    
    if string.contains(k,"nixie") then
      global.vehicleMap[k] = nil
    elseif string.contains(k,"heli") or string.contains(k,"rotor") then
      global.vehicleMap[k] = nil
    elseif k == "uplink-station" then
      global.vehicleMap[k] = nil
    elseif k == "vwtransportercargo" then
      global.vehicleMap[k] = nil
    elseif string.contains(k,"airborne") then
      global.vehicleMap[k] = nil
    elseif string.contains(k,"cargo%-plane") then
      global.vehicleMap[k] = "loaded-vehicle-wagon-cargoplane"
    elseif k == "jet" then
      global.vehicleMap[k] = "loaded-vehicle-wagon-jet"
    elseif k == "gunship" then
      global.vehicleMap[k] = "loaded-vehicle-wagon-gunship"
    elseif k == "dumper-truck" then
      global.vehicleMap[k] = "loaded-vehicle-wagon-truck"
    elseif string.contains(k,"ht%-RA") then
      global.vehicleMap[k] = "loaded-vehicle-wagon-tank"
    elseif string.contains(k,"tank") then
      global.vehicleMap[k] = "loaded-vehicle-wagon-tank"
    elseif string.contains(k,"car") then
      global.vehicleMap[k] = "loaded-vehicle-wagon-car"
    else
      global.vehicleMap[k] = "loaded-vehicle-wagon-tarp"
    end

  end
  
  global.loadedWagonMap = {}
  global.loadedWagonList = {}
  global.loadedWagonFlip = {}
  for _,v in pairs(global.vehicleMap) do
    if not global.loadedWagonMap[v] then
      global.loadedWagonMap[v] = "vehicle-wagon"
      table.insert(global.loadedWagonList, v)
    end
  end
  
  global.loadedWagonFlip["loaded-vehicle-wagon-gunship"] = true
  global.loadedWagonFlip["loaded-vehicle-wagon-jet"] = true
  global.loadedWagonFlip["loaded-vehicle-wagon-cargoplane"] = true

end

function migrateWagonData(id)
  local migrated = false
  if global.wagon_data[id].items then
    -- First migrate grid
    if global.wagon_data[id].items.grid then
      for _,v in pairs(global.wagon_data[id].items.grid) do
        if v.name then
          v.item = {name=v.name, position=v.position}
          migrated = true
        end
      end
    end
    -- Then migrate items
    for k,v in pairs(global.wagon_data[id].items) do
      -- anything besides fuel, ammo, trunk, and grid are names of items
      if type(v) == "number" then
        global.wagon_data[id].items.general = global.wagon_data[id].items.general or {}
        global.wagon_data[id].items.general[k] = v
        migrated = true
      end
    end
    -- Then migrate filters
    if global.wagon_data[id].filters then
      if global.wagon_data[id].filters[2] then
        global.wagon_data[id].filters.ammo = global.wagon_data[id].filters[2]
        migrated = true
      end
      if global.wagon_data[id].filters[3] then
        global.wagon_data[id].filters.trunk = global.wagon_data[id].filters[3]
        migrated = true
      end
    end
  end
  return migrated
end


function ScrubDataTables()
-- Scrub tables to remove references to non-existent loaded wagons and non-existent players
  local all_wagons = {}
  for _,surface in pairs(game.surfaces) do
    local new_wagons = surface.find_entities_filtered{name=global.loadedWagonList}
    for _,nw in pairs(new_wagons) do
      game.print("Found loaded wagon "..nw.unit_number..": "..nw.name)
      table.insert(all_wagons, nw)
    end
  end
  for id,data in pairs(global.wagon_data) do
    local found = false
    for _,wagon in pairs(all_wagons) do
      if wagon.unit_number == id then
        found = true
        break
      end
    end
    for pid,_ in pairs(game.players) do
      if pid == id then
        found = true
        break
      end
    end
    if found == false then
      -- Purge data
      global.wagon_data[id] = nil
      game.print("Purged loaded wagon data for unit or player "..id)
    else
      -- Wagon valid, Migrate data if needed
      if migrateWagonData(id) then
        game.print("Migrated loaded wagon data for unit or player "..id)
      end
    end
  end
  
  for id,data in pairs(global.vehicle_data) do
    local found = false
    for pid,_ in pairs(game.players) do
      if pid == id then
        found = true
        break
      end
    end
    if found == false then
      -- Purge data
      global.vehicle_data[id] = nil
      game.print("Purged vehicle data for player "..id)
    end
  end
end


--== ON_INIT EVENT ==--
-- Initialize global data tables
function On_Init()
  global.vehicle_data = global.vehicle_data or {}
  global.wagon_data = global.wagon_data or {}
  global.tutorials = global.tutorials or {}
  for i, player in pairs(game.players) do
    global.tutorials[player.index] = {}
  end
  
  InitializeTypeMapping()
  
  ScrubDataTables()
  
end

--== ON_LOAD EVENT ==--
-- Enable on_tick event according to global variable state
function On_Load()
  if global.found then
    script.on_event(defines.events.on_tick, process_tick)
  end
end

-- Deal with the new 0.16 driver/passenger bit
function get_driver_or_passenger(entity)
  -- Check if we have a driver:
  local driver = entity.get_driver()
  if driver then return driver end

  -- Otherwise check if we have a passenger, which will error if entity is not a car:
  local status, resp = pcall(entity.get_passenger)
  if not status then return nil end
  return resp
end


-------------------------
-- Unload Wagon (either manually or from mining)
function unloadWagon(loaded_wagon, player)
  
  -- Get data associated with the vehicle stored on this wagon
  local wagon_data = global.wagon_data[loaded_wagon.unit_number]
  local player_index = nil
  if player then
    player_index = player.index
  end
  local surface = loaded_wagon.surface
  
  -- Store wagon details for replacement
  local wagon_position = loaded_wagon.position
  
  -- Ask game for a valid unloading position near the wagon
  local unload_position = nil
  if global.wagon_data[player_index] then
    unload_position = global.wagon_data[player_index].unload_position
  end
  if not unload_position then
    unload_position = surface.find_non_colliding_position(wagon_data.name, wagon_position, 5, 1)
  end
  if not unload_position then
    if player then
      player.print({"position-error"})
    else
      game.print({"position-error"})
    end
    return
  end
  
  local force = loaded_wagon.force
  if player then
    force = player.force
  end
  
  local direction = math.floor(loaded_wagon.orientation*8 + 0.5)
  if global.loadedWagonFlip[loaded_wagon.name] then
    direction = math.fmod(direction + 4, 8)
  end
  
  -- Create the vehicle
  local vehicle = surface.create_entity{
                      name = wagon_data.name, 
                      position = unload_position, 
                      force = force,
                      direction = direction
                    }
  if not vehicle then
    if player then
      player.print({"generic-error"})
    else
      game.print({"generic-error"})
    end
    return vehicle
  end
  
  -- Restore vehicle parameters from global data
  vehicle.health = wagon_data.health
  if wagon_data.color then 
    vehicle.color = wagon_data.color
  end
  
  -- Restore inventory filters
  if wagon_data.filters then
    restoreFilters(vehicle.get_inventory(defines.inventory.car_ammo), wagon_data.filters.ammo)
    restoreFilters(vehicle.get_inventory(defines.inventory.car_trunk), wagon_data.filters.trunk)
  end
  
  -- Restore inventory contents
  saveRestoreLib.restoreInventory(vehicle.get_inventory(defines.inventory.car_ammo), wagon_data.items.ammo)
  saveRestoreLib.restoreInventory(vehicle.get_inventory(defines.inventory.car_trunk), wagon_data.items.trunk)
  saveRestoreLib.restoreInventory(vehicle, wagon_data.items.general, true) -- migrated items inserted directly to car entity
  if vehicle.grid and vehicle.grid.valid then
    saveRestoreLib.restoreGrid(vehicle.grid, wagon_data.items.grid, player_index)
  end
  
  -- Restore burner
  saveRestoreLib.restoreBurner(vehicle.burner, wagon_data.burner)
  
  -- Raise event for scripts
  script.raise_event(defines.events.script_raised_built, {entity = vehicle, player_index = player_index})
  
  -- Finished creating vehicle, clear loaded wagon data
  global.wagon_data[loaded_wagon.unit_number] = nil
  
  -- Play sounds associated with creating the vehicle
  surface.play_sound({path = "latch-off", position = unload_position, volume_modifier = 0.7})
  
  -- Replace loaded wagon with unloaded wagon
  local wagon = replaceCarriage(loaded_wagon, "vehicle-wagon", false, false)
  
  -- Check that unloaded wagon was created correctly
  if wagon and wagon.valid then
    -- Play sound associated with creating the unloaded wagon
    surface.play_sound({path = "utility/build_medium", position = unload_position, volume_modifier = 0.7})
  else
    if player then
      player.print({"generic-error"})
    else
      game.print({"generic-error"})
    end
  end
  
  return vehicle
end

-------------------------
-- Load Wagon
function loadWagon(player)
  local player_index = player.index
  local player_data = global.wagon_data[player_index]
  
  local wagon = player_data.wagon
  local vehicle = player_data.vehicle
  local surface = wagon.surface
  
  -- Save parameters of empty wagon
  local position = wagon.position
  
  -- Find direction for wagon (either as-is or rotate 180)
  local flip = (math.abs(vehicle.orientation - wagon.orientation) > 0.25)
  if global.loadedWagonFlip[player_data.name] then
    flip = not flip
  end
  
  -- Replace the unloaded wagon with loaded one
  local loaded_wagon = replaceCarriage(wagon, player_data.name, false, false, flip)
  
  -- Check that loaded wagon was created correctly
  if not loaded_wagon or not loaded_wagon.valid then
    -- Unable to create the loaded wagon, don't delete vehicle
    player.print({"generic-error"})
    return
  end
  
  -- Play sound associated with creating loaded wagon
  surface.play_sound({path = "utility/build_medium", position = position, volume_modifier = 0.7})
  
  -- Store data on vehicle in global table
  global.wagon_data[loaded_wagon.unit_number] = {}
  
  -- Store vehicle entity name (either normal or AAI)
  if remote.interfaces["aai-programmable-vehicles"] then
    -- Make sure we need the 'expensive' gsub call before bothering:
    -- AAI vehicles end up with a composite; ex. for a vehicle-miner, the actual object that gets
    -- loaded is a 'vehicle-miner-_-solid', which when unloaded doesn't work unless we record
    -- into the base object here.
    -- NOTE: Unfortunately unloaded vehicles still end up with a new unit ID, as AAI doesn't expose
    -- an interface to set/restore the vehicles unit ID.
    global.wagon_data[loaded_wagon.unit_number].name = string.gsub(vehicle.name, "%-_%-.+","")
  else
    global.wagon_data[loaded_wagon.unit_number].name = vehicle.name
  end
  
  -- Store vehicle parameters
  global.wagon_data[loaded_wagon.unit_number].health = vehicle.health
  global.wagon_data[loaded_wagon.unit_number].color = vehicle.color
  
  -- Store inventory contents
  global.wagon_data[loaded_wagon.unit_number].items = {}
  global.wagon_data[loaded_wagon.unit_number].items.ammo = saveRestoreLib.saveInventory(vehicle.get_inventory(defines.inventory.car_ammo))
  global.wagon_data[loaded_wagon.unit_number].items.trunk = saveRestoreLib.saveInventory(vehicle.get_inventory(defines.inventory.car_trunk))
  global.wagon_data[loaded_wagon.unit_number].items.grid = saveRestoreLib.saveGrid(vehicle.grid)
  
  -- Store inventory filters
  global.wagon_data[loaded_wagon.unit_number].filters = {}
  global.wagon_data[loaded_wagon.unit_number].filters.ammo = saveRestoreLib.saveFilters(vehicle.get_inventory(defines.inventory.car_ammo))
  global.wagon_data[loaded_wagon.unit_number].filters.trunk = saveRestoreLib.saveFilters(vehicle.get_inventory(defines.inventory.car_trunk))
  
  -- Store vehicle burner
  global.wagon_data[loaded_wagon.unit_number].burner = saveRestoreLib.saveBurner(vehicle.burner)
  
  -- Destroy vehicle
  vehicle.destroy()
  
end

--== ON_TICK EVENT ==--
-- Executes queued load/unload actions after the correct time has elapsed.
function process_tick(event)
  global.found = false  -- Flag stays false when no player_data remains in queue
  local current_tick = event.tick
  
  -- Loop through players to see if any of them requested load/unload
  --   (would be better to have a separate global queue)
  for i, player in pairs(game.players) do
  
    local player_index = player.index
    local player_data = global.wagon_data[player_index]
    
    if player_data then
    
      global.found = true  -- Set flag true, since player_data still exists in queue
      
      ------- LOADING OPERATION --------
      if player_data.status == "load" and player_data.tick == current_tick then
        -- Clear capsule sequence display
        player.clear_gui_arrow()
        
        -- Check that the wagon and vehicle indicated by the player are a valid target for loading
        local wagon = player_data.wagon
        local vehicle = player_data.vehicle
        if not vehicle or not wagon or not vehicle.valid or not wagon.valid then
          player.print({"generic-error"})
        elseif wagon.get_driver() or get_driver_or_passenger(vehicle) then
          player.print({"passenger-error"})
        elseif wagon.train.speed ~= 0 then
          player.print({"train-in-motion-error"})
        else
          -- Execute the loading for this player if possible.
          loadWagon(player)
        end
        
        -- Whether or not loading succeeds, clear this player request
        global.wagon_data[player_index] = nil
        
      ------- UNLOADING OPERATION --------
      elseif global.wagon_data[player_index].status == "unload" and global.wagon_data[player_index].tick == current_tick then
        -- Clear capsule sequence display
        player.clear_gui_arrow()
        
        -- Check that the wagon indicated by the player is a valid target for unloading
        local wagon_data = global.wagon_data[player_index]
        if wagon_data then
          local loaded_wagon = wagon_data.wagon
          if not loaded_wagon or not loaded_wagon.valid then
            player.print({"generic-error"})
          elseif loaded_wagon.get_driver() then
            player.print({"passenger-error"})
          elseif loaded_wagon.train.speed ~= 0 then
            player.print({"train-in-motion-error"})
          else
            -- Execute unloading if possible.  Vehicle object returned if successful
            unloadWagon(loaded_wagon, player)
          end
        else
          player.print({"generic-error-"})
        end
        -- Whether or not unloading succeeds, clear this player request data
        global.wagon_data[player_index] = nil
        
      end
    end
  end
  
  -- Unsubscribe from on_tick if no player_data remains in queue
  if not global.found then
    script.on_event(defines.events.on_tick, nil)
  end
end


-- Starts loading process if capsule use is correct
function queueLoadWagon(wagon, vehicle, player_index, name)
  local player = game.players[player_index]
  player.surface.play_sound({path = "winch-sound", position = player.position})
  global.wagon_data[player_index] = {}
  global.wagon_data[player_index].status = "load"
  global.wagon_data[player_index].wagon = wagon
  global.wagon_data[player_index].vehicle = vehicle
  global.wagon_data[player_index].name = name
  global.wagon_data[player_index].tick = game.tick + 120
  script.on_event(defines.events.on_tick, process_tick)
end

-- Starts unloading process if capsule use is correct
function queueUnloadWagon(loaded_wagon, player_index)
  local player = game.players[player_index]
  player.surface.play_sound({path = "winch-sound", position = player.position})
  global.wagon_data[player_index].status = "unload"
  global.wagon_data[player_index].tick = game.tick + 120
  script.on_event(defines.events.on_tick, process_tick)
end


-- Handles when player clicks on loaded wagon with winch capsule
function handleLoadedWagon(loaded_wagon, player_index)
  local player = game.players[player_index]
  global.tutorials[player_index] = global.tutorials[player_index] or {}
  global.tutorials[player_index][2] = global.tutorials[player_index][2] or 0
  if loaded_wagon.get_driver() then
    player.print({"passenger-error"})
  elseif loaded_wagon.train.speed ~= 0 then
    player.print({"train-in-motion-error"})
  elseif not global.wagon_data[loaded_wagon.unit_number] then
    game.print("ERROR: Missing global data for unit "..loaded_wagon.unit_number)  
    -- Loaded wagon data or vehicle entity is invalid
    -- Replace wagon with unloaded version and delete data
    replaceCarriage(loaded_wagon, "vehicle-wagon", false, false)
  elseif not game.entity_prototypes[global.wagon_data[loaded_wagon.unit_number].name] then
    game.print("ERROR: Missing prototype \""..global.wagon_data[loaded_wagon.unit_number].name.."\" for unit "..loaded_wagon.unit_number)  
    -- Loaded wagon data or vehicle entity is invalid
    -- Replace wagon with unloaded version and delete data
    global.wagon_data[loaded_wagon.unit_number] = nil
    replaceCarriage(loaded_wagon, "vehicle-wagon", false, false)
  else
    player.play_sound({path = "latch-on"})
    player.set_gui_arrow({type = "entity", entity = loaded_wagon})
    if global.tutorials[player_index][2] < 5 then
      global.tutorials[player_index][2] = global.tutorials[player_index][2] + 1
      player.print({"select-unload-vehicle-location"})
    end
    global.wagon_data[player_index] = {}
    global.wagon_data[player_index].wagon = loaded_wagon
  end
end

-- Handles when player clicks on empty wagon with winch capsule
function handleWagon(wagon, player_index)
  local player = game.players[player_index]
  if wagon.get_driver() then
    player.print({"passenger-error"})
  elseif wagon.train.speed ~= 0 then
    player.print({"train-in-motion-error"})
  elseif global.vehicle_data[player_index] then
    local vehicle = global.vehicle_data[player_index]
    if not vehicle.valid then
      global.vehicle_data[player_index] = nil
      player.clear_gui_arrow()
      player.print({"generic-error"})
    elseif get_driver_or_passenger(vehicle) then
      global.vehicle_data[player_index] = nil
      player.clear_gui_arrow()
      player.print({"passenger-error"})
    elseif Position.distance(wagon.position, vehicle.position) > 9 then
      player.print({"too-far-away"})
    else
      local loadedName = global.vehicleMap[vehicle.name]
      if not loadedName then
        global.vehicle_data[player_index] = nil
        player.clear_gui_arrow()
        player.print({"unknown-vehicle-error"})
      else
        queueLoadWagon(wagon, vehicle, player_index, loadedName)
      end
    end
  else
    player.print({"no-vehicle-selected"})
  end
end


-- Handles when player clicks on vehicle with winch capsule
function handleVehicle(vehicle, player_index)
  local player = game.players[player_index]
  global.tutorials[player_index] = global.tutorials[player_index] or {}
  global.tutorials[player_index][1] = global.tutorials[player_index][1] or 0
  if get_driver_or_passenger(vehicle) then
    player.print({"passenger-error"})
  else
    global.vehicle_data[player_index] = vehicle
    player.set_gui_arrow({type = "entity", entity = vehicle})
    player.play_sound({path = "latch-on"})
    if global.tutorials[player_index][1] < 5 then
      global.tutorials[player_index][1] = global.tutorials[player_index][1] + 1
      player.print({"vehicle-selected"})
    end
  end
end

--== ON_PLAYER_USED_CAPSULE ==--
-- Queues load/unload data when player clicks with the winch.
script.on_event(defines.events.on_player_used_capsule, function(event)
  local capsule = event.item
  if capsule.name == "winch" then
    local index = event.player_index
    local player = game.players[index]
    local surface = player.surface
    local position = event.position
    local vehicle = surface.find_entities_filtered{type = "car", position = position, force = player.force}
    local wagon = surface.find_entities_filtered{name = "vehicle-wagon", position = position, force = player.force}
    local loaded_wagon = surface.find_entities_filtered{name = global.loadedWagonList, position = position, force = player.force}
    
    vehicle = vehicle[1]
    wagon = wagon[1]
    loaded_wagon = loaded_wagon[1]
    if loaded_wagon and loaded_wagon.valid then
      handleLoadedWagon(loaded_wagon, index)
    elseif wagon and wagon.valid then
      handleWagon(wagon, index)
    elseif vehicle and vehicle.valid then
      handleVehicle(vehicle, index)
    elseif global.wagon_data[index] and global.wagon_data[index].wagon and not global.wagon_data[index].status then
      local wagon = global.wagon_data[index].wagon
      local unload_position = player.surface.find_non_colliding_position(global.wagon_data[wagon.unit_number].name, position, 5, 1)
      if not unload_position then
        player.print({"position-error"})
      elseif Position.distance(wagon.position, unload_position) > 9 then
        player.print({"too-far-away"})
      else
        global.wagon_data[index].unload_position = unload_position
        queueUnloadWagon(wagon, index)
      end
    end
    player.insert{name = "winch", count = 1}
  end
end)


-- Table showing which entities can be unloaded
function isLoadedWagon(entity)
  if global.loadedWagonMap[entity.name] then
    return true
  else
    return false
  end
end


function insertIntoRobot(inventory, items)
  -- get first item in list
  local name,count = next(items)
  if not name then return 0 end
  game.print("Trying to give robot "..name..":"..tostring(count))
  -- try to insert this many, rounding up if fractional
  local inserted = inventory.insert({name=name, count=math.ceil(count)})
  -- handle fractional
  if inserted > count then  -- fractional stack, added the last one
    local stack = inventory.find_item_stack(name)  -- apply fractional value to any stack of this type
    local magazine = stack.prototype.magazine_size  -- nil if not ammo
    local durability = stack.prototype.durability  -- nil if not durable
    local f
    _,f = math.modf(count)  -- find fractional value of last item
    if magazine and f > 0 then
      stack.ammo = math.floor(f*magazine+0.5)  -- set ammo to fractional value
    elseif durability and f > 0 then
      stack.durability = math.floor(f*durability+0.5)  -- set durability to fractional value
    end
  end
  -- remove that many from list, rounding down if fractional
  items[name] = math.max(0, items[name] - inserted)
  -- clear item if empty
  if items[name] == 0 then
    items[name] = nil
  end
  if table_size(items) == 0 then
    items = nil
  end
  game.print("Gave robot "..name..":"..tostring(inserted))
  return inserted
end

--== ON_PRE_PLAYER_MINED_ITEM ==--
--== ON_ROBOT_PRE_MINED ==--
-- When player mines a loaded wagon, try to unload the vehicle first!
script.on_event({defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined}, function(event)
  local entity = event.entity
  if isLoadedWagon(entity) then
    local keepData = false
    
    -- Player or robot is mining a loaded wagon
    -- Attempt to unload the wagon nearby
    local unit_number = entity.unit_number
    local player_index = event.player_index
    
    local player = nil
    if player_index then
      player = game.players[player_index]
    end
    local wagon_data = global.wagon_data[unit_number]
    if not wagon_data then
      -- No data on this loaded wagon
      if player then
        player.print({"generic-error"})
      else
        game.print({"generic-error"})
      end
    else
      -- We can try to unload this wagon
      local vehicle = unloadWagon(entity, player)
      
      if not vehicle then
        -- Vehicle could not be unloaded
        if player then
          -- Insert vehicle and contents into player's inventory
          player.print({"position-error"})
          local text_position = player.position
          text_position.y = text_position.y + 1
          player.insert{name = wagon_data.name, count = 1}
          player.surface.create_entity({name = "flying-text", position = text_position, text = {"item-inserted", 1, game.entity_prototypes[wagon_data.name].localised_name}})
          insertItems(player, wagon_data.items, event.player_index, true, true)
        else
          -- Robot can't carry vehicle, give it contents instead
          game.print("NOTICE: Loaded Vehicle Wagon could not be unloaded by robot.  Vehicle lost.")
          -- First check for inventory contents
          local inventory = event.robot.get_inventory(defines.inventory.robot_cargo)
          local inserted = 0
          if wagon_data.items.general then
            inserted = insertIntoRobot(inventory, wagon_data.items.general)
          end
          if inserted == 0 and wagon_data.items.trunk then
            inserted = insertIntoRobot(inventory, wagon_data.items.trunk)
          end
          if inserted == 0 and wagon_data.items.ammo then
            inserted = insertIntoRobot(inventory, wagon_data.items.ammo)
          end
          if inserted == 0 and wagon_data.burner.inventory then
            inserted = insertIntoRobot(inventory, wagon_data.burner.inventory)
          end
          if inserted == 0 and wagon_data.items.grid then
            k,equip = next(wagon_data.items.grid)
            if equip then
              if equip.burner and equip.burner.inventory then
                inserted = insertIntoRobot(inventory, equip.burner.inventory)
              end
              if inserted == 0 and equip.burner and equip.burner.burnt_result_inventory then
                inserted = insertIntoRobot(inventory, equip.burner.burnt_result_inventory)
              end
              if inserted == 0 then
                inserted = inventory.insert({name=equip.item.name, count=1})
                if inserted > 0 then
                  game.print("Gave robot "..equip.item.name..":1")
                  wagon_data.items.grid[k] = nil
                  if table_size(wagon_data.items.grid) == 0 then
                    wagon_data.items.grid = nil
                  end
                end
              end
            end
          end
          if inserted == 0 then             
            inventory.insert(wagon_data.name)
            local stack = inventory.find_item_stack(wagon_data.name)
            if not stack.grid then
              game.print("Vehicle stack has nil grid")
            elseif wagon_data.items.grid and stack and stack.grid and stack.grid.valid then
              game.print("Trying to restore grid")
              saveRestoreLib.restoreGrid(stack.grid, wagon_data.items.grid)
            end
            game.print("Gave robot "..wagon_data.name..":1")
            replaceCarriage(entity, "vehicle-wagon", false, false)
          else
            keepData = true
          end
        end
      end
      
    end
    
    -- Delete the data associated with the mined wagon unless robots are unloading it
    if not keepData then
      global.wagon_data[unit_number] = nil
    end
  end
end)


--== ON_MARKED_FOR_DECONSTRUCTION ==--
-- When player marks loaded wagon for deconstruction, check if there is space for the robot to unload the vehicle.
-- script.on_event(defines.events.on_marked_for_deconstruction, function(event)
  -- local entity = event.entity
  -- if isLoadedWagon(entity) then
    -- local unit_number = entity.unit_number
    -- local wagon_data = global.wagon_data[unit_number]
    -- if wagon_data then
      -- -- Check if there is space
      -- local unload_position = entity.surface.find_non_colliding_position(wagon_data.name, entity.position, 5, 1)
      -- if not unload_position then
        -- -- No space to unload nearby
        -- -- Display error message
        -- if event.player then
          -- player.print("Deconstruction cancelled: no space for robot to unload "..wagon_data.name.." from wagon.")
        -- else
          -- game.print("Deconstruction cancelled: no space for robot to unload "..wagon_data.name.." from wagon.")
        -- end
        -- -- Try to remove deconstruction order
        -- for _,force in pairs(game.forces) do
          -- if entity.to_be_deconstructed(force) then
            -- entity.cancel_deconstruction(force)
          -- end
        -- end
      -- end
    -- end
  -- end
-- end)


--== ON_ENTITY_DIED ==--
--== SCRIPT_RAISED_DESTROY ==--
-- When a loaded wagon dies or is destroyed by a different mod, delete its vehicle data
script.on_event({defines.events.on_entity_died, defines.events.script_raised_destroy}, function(event)
  local entity = event.entity
  if isLoadedWagon(entity) then
    -- Loaded wagon died, its vehicle is unrecoverable
    -- Clear data for this wagon
    global.wagon_data[entity.unit_number] = nil
  end
end)


--== ON_PLAYER_CURSOR_STACK_CHANGED EVENT ==--
-- When player stops holding winch, abort any in-progress load/unload operations
script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
  local player = game.players[event.player_index]
  local index = event.player_index
  local stack = player.cursor_stack
  if not stack or not stack.valid or not stack.valid_for_read or not (stack.name == "winch") then
    if not global.found then
      player.clear_gui_arrow()
    end
    if ((global.vehicle_data[index] and global.vehicle_data[index].valid) or (global.wagon_data[index] and global.wagon_data[index].wagon)) and not global.found then
      player.play_sound({path = "latch-off"})
    end
    global.vehicle_data[index] = nil
    if global.wagon_data[index] and global.wagon_data[index].wagon and not global.wagon_data[index].status then
      global.wagon_data[index] = nil
    end
  end
end)


--== ON_PLAYER_DRIVING_CHANGED_STATE EVENT ==--
-- Eject player from unloaded wagon
-- Can't ride on an empty flatcar, but you can in a loaded one
script.on_event(defines.events.on_player_driving_changed_state, function(event)
  local player = game.players[event.player_index]
  if player.vehicle and player.vehicle.name == "vehicle-wagon" then
    player.driving = false
  end
end)


------------------------- CURSOR AND BLUEPRINT HANDLING FOR 0.17.x ---------------------------------------

--== ON_PLAYER_PIPETTE ==--
-- Fires when player presses 'Q'.  We need to sneakily grab the correct item from inventory if it exists,
--  or sneakily give the correct item in cheat mode.
script.on_event(defines.events.on_player_pipette, function(event) mapPipette(event,global.loadedWagonMap) end)

--== ON_PLAYER_CONFIGURED_BLUEPRINT EVENT ==--
-- ID 70, fires when you select a blueprint to place
--== ON_PLAYER_SETUP_BLUEPRINT EVENT ==--
-- ID 68, fires when you select an area to make a blueprint or copy
-- Force Blueprints to only store empty vehicle wagons
script.on_event({defines.events.on_player_setup_blueprint,
                 defines.events.on_player_configured_blueprint}, function(event) mapBlueprint(event,global.loadedWagonMap) end)

------------------------------------------
-- Debug (print text to player console)
function debug(...)
  if global.debug then
    print_game(...)
  end
end

function print_game(...)
  text = ""
  for _, v in ipairs{...} do
    if type(v) == "table" then
      text = text..serpent.block(v)
    else
      text = text..tostring(v)
    end
  end
  game.print(text)
end

function print_file(...)
  text = ""
  for _, v in ipairs{...} do
    if type(v) == "table" then
      text = text..serpent.block(v)
    else
      text = text..tostring(v)
    end
  end
  log(text)
end  

-- Debug command
function cmd_debug(params)
  toogle = params.parameter
  if not toogle then
    if global.debug then
      toogle = "disable"
    else
      toogle = "enable"
    end
  end
  if toogle == "disable" then
    global.debug = false
    print_game("Debug mode disabled")
  elseif toogle == "enable" then
    global.debug = true
    print_game("Debug mode enabled")
  elseif toogle == "dump" then
    for v, data in pairs(global) do
      print_game(v, ": ", data)
    end
  elseif toogle == "dumplog" then
    for v, data in pairs(global) do
      print_file(v, ": ", data)
    end
    print_game("Dump written to log file")
  end
end
commands.add_command("vehicle-wagon-debug", {"command-help.vehicle-wagon-debug"}, cmd_debug)
