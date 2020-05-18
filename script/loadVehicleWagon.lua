--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: loadVehicleWagon.lua
 * Description:  Function to execute the given Loading Action.
 *    1. Replace empty Vehicle Wagon with the requested Loaded Vehicle Wagon.
 *    2. Store the Vehicle inventories, grid, and settings in the global.wagon_data table.
 --]]


-------------------------
-- Load Wagon
function loadVehicleWagon(action)
  local player_index = action.player_index
  
  local wagon = action.wagon
  local vehicle = action.vehicle
  local surface = wagon.surface
  
  -- Save parameters of empty wagon
  local position = wagon.position
  
  -- Find direction for wagon (either as-is or rotate 180)
  local flip = (math.abs(vehicle.orientation - wagon.orientation) > 0.25)
  if global.loadedWagonFlip[action.name] then
    flip = not flip
  end
  
  -- Replace the unloaded wagon with loaded one
  local loaded_wagon = replaceCarriage(wagon, action.name, false, false, flip)
  
  -- Check that loaded wagon was created correctly
  if not loaded_wagon or not loaded_wagon.valid then
    -- Unable to create the loaded wagon, don't delete vehicle
    -- replaceCarriage will drop the wagon on the ground for player to pick up
    player.print({"vehicle-wagon2.loaded-wagon-error"})
    return
  end
  
  -- Play sound associated with creating loaded wagon
  surface.play_sound({path = "utility/build_medium", position = position, volume_modifier = 0.7})
  
  -- Store data on vehicle in global table
  local unit_number = loaded_wagon.unit_number
  local saveData = {}
  
  -- Store vehicle parameters
  saveData.name = vehicle.name
  saveData.health = vehicle.health
  saveData.color = vehicle.color
  saveData.last_user = vehicle.last_user
  
  -- Store inventory contents
  saveData.items = {
                     ammo = saveRestoreLib.saveInventoryStacks(vehicle.get_inventory(defines.inventory.car_ammo)),
                     trunk = saveRestoreLib.saveInventoryStacks(vehicle.get_inventory(defines.inventory.car_trunk))
                   }
  
  -- Store inventory filters
  saveData.filters = {ammo = saveRestoreLib.saveFilters(vehicle.get_inventory(defines.inventory.car_ammo)),
                      trunk = saveRestoreLib.saveFilters(vehicle.get_inventory(defines.inventory.car_trunk)) }
  
  -- Store grid contents
  saveData.grid = saveRestoreLib.saveGrid(vehicle.grid)
  
  -- Store vehicle burner
  saveData.burner = saveRestoreLib.saveBurner(vehicle.burner)
  
  -- Store data for other mods
  if remote.interfaces["autodrive"] then
    -- This will return a table with just { owner = player.index } for now!
    saveData.autodrive_data = remote.call("autodrive", "get_vehicle_data", vehicle.unit_number)
    remote.call("autodrive", "vehicle_removed", vehicle)
  end
  if remote.interfaces["GCKI"] then
    -- This will return a table with { owner = player.index, locker = player.index }
    saveData.GCKI_data = remote.call("GCKI", "get_vehicle_data", vehicle.unit_number)
    remote.call("GCKI", "vehicle_removed", vehicle)
    if saveData.GCKI_data then
      -- There is an owner or a locker of this wagon.  Make it un-minable.
      -- Issue: if owner claims another car, it un-claims the vehicle in this wagon, but we won't make this minable again.
      loaded_wagon.minable = false
    end
  end
  
  global.wagon_data[unit_number] = saveData
  
  -- Destroy vehicle
  vehicle.destroy({raise_destroy=true})
  
end
