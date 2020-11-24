--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: loadVehicleWagon.lua
 * Description:  Function to execute the given Loading Action.
 *    1. Replace empty Vehicle Wagon with the requested Loaded Vehicle Wagon.
 *    2. Store the Vehicle inventories, grid, and settings in the global.wagon_data table.
 --]]

-- defines.inventory.SPIDER_TRUNK = 2
-- defines.inventory.SPIDER_AMMO = 3

local SPIDER_TRUNK = 2
local SPIDER_AMMO = 3

local SURFACE_NAME = "vehicle-wagon-storage"

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
  
  -- Save reference to loaded wagon entity
  saveData.wagon = loaded_wagon
  
  -- Save reference to loaded vehicle
  saveData.vehicle = vehicle
  
  -- Teleport vehicle to storage surface
  local vwsurf = game.get_surface(SURFACE_NAME)
  if vwsurf == nil then
    vwsurf = game.create_surface(SURFACE_NAME, {
        terrain_segmentation = 1,
        water = 0,
        autoplace_controls = {},
        default_enable_all_autoplace_controls = false,
        autoplace_settings = {"tile" = {treat_missing_as_default=false, settings={"refined-concrete"={frequency=2,size=2,richness=2}}}},
        cliff_settings = nil,
        seed = 0,
        width = 1000,
        height = 1000,
        starting_area = 0,
        starting_points = {},
        peaceful_mode = true,
        property_expression_names = {}
      }
    )
  end
  
  local target_pos = vwsurf.find_non_colliding_position(vehicle.name, {0,0}, 1000, 1)
  if not target_pos then
    game.print("Oops, couldn't find position in storage realm")
    return
  end
  if not vehicle.teleport(target_pos, vwsurf) then
    game.print("Oops, couldn't teleport vehicle into storage")
    return
  end
  
  
  
  --[[
  
  -- Store vehicle parameters
  saveData.name = vehicle.name
  saveData.health = vehicle.health
  saveData.color = vehicle.color
  saveData.last_user = vehicle.last_user and vehicle.last_user.index
  if not vehicle.minable then saveData.minable = false end
  if not vehicle.destructible then saveData.destructible = false end
  if not vehicle.operable then saveData.operable = false end
  if not vehicle.rotatable then saveData.rotatable = false end
  if not vehicle.enable_logistics_while_moving then saveData.enable_logistics_while_moving = false end
  
  
  if vehicle.type == "car" then
    -- Store inventory contents
    saveData.items = {
                       ammo = saveRestoreLib.saveInventoryStacks(vehicle.get_inventory(defines.inventory.car_ammo)),
                       trunk = saveRestoreLib.saveInventoryStacks(vehicle.get_inventory(defines.inventory.car_trunk))
                     }
    
    -- Store inventory filters
    saveData.filters = {ammo = saveRestoreLib.saveFilters(vehicle.get_inventory(defines.inventory.car_ammo)),
                        trunk = saveRestoreLib.saveFilters(vehicle.get_inventory(defines.inventory.car_trunk)) }
  elseif vehicle.type == "spider-vehicle" then
    -- Store inventory contents
    saveData.items = {
                       ammo = saveRestoreLib.saveInventoryStacks(vehicle.get_inventory(SPIDER_AMMO)),
                       trunk = saveRestoreLib.saveInventoryStacks(vehicle.get_inventory(SPIDER_TRUNK))
                     }
    
    -- Store inventory filters
    saveData.filters = {ammo = saveRestoreLib.saveFilters(vehicle.get_inventory(SPIDER_AMMO)),
                        trunk = saveRestoreLib.saveFilters(vehicle.get_inventory(SPIDER_TRUNK)) }
  end
  
  -- Store grid contents
  saveData.grid = saveRestoreLib.saveGrid(vehicle.grid)
  
  -- Store vehicle burner
  saveData.burner = saveRestoreLib.saveBurner(vehicle.burner)
  
  -- Store data for other mods
  if remote.interfaces["autodrive"] and remote.interfaces["autodrive"].get_vehicle_data then
    -- This will return a table with just { owner = player.index } for now!
    saveData.autodrive_data = remote.call("autodrive", "get_vehicle_data", vehicle.unit_number, script.mod_name)
    remote.call("autodrive", "vehicle_removed", vehicle)
  end
  if remote.interfaces["GCKI"] and remote.interfaces["GCKI"].get_vehicle_data then
    -- This will return a table with { owner = player.index, locker = player.index }
    saveData.GCKI_data = remote.call("GCKI", "get_vehicle_data", vehicle.unit_number)
    remote.call("GCKI", "vehicle_removed", vehicle, script.mod_name)
    if saveData.GCKI_data and settings.global["vehicle-wagon-use-GCKI-permissions"].value then
      if saveData.GCKI_data.owner or saveData.GCKI_data.locker then
        -- There is an owner or a locker of the vehicle on this wagon.  Make it un-minable.
        -- GCKI will call an interface function to release it if the owner unclaims it.
        loaded_wagon.minable = false
      end
    end
  end
  
  --]]
  
  -- Put an icon on the wagon showing contents
  saveData.icon = renderIcon(loaded_wagon, vehicle.name)
  
  global.wagon_data[unit_number] = saveData
  
  -- Destroy vehicle. Raise event with custom parameter so we don't immediately clear the loading ramp.
  script.raise_event(defines.events.script_raised_destroy, {entity=vehicle, vehicle_loaded=true})
  vehicle.destroy({raise_destroy=false})
  
end
