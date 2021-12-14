--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: helpers.lua
 * Description:  Helper functions to use during the data stage.
 --]]


function makeDummyItem(name)
  return {
      type = "item",
      name = name,
      icon = "__VehicleWagon2__/graphics/icons/vehicle-wagon-icon.png",
      icon_size = 64,
      flags = {"hidden"},
      subgroup = "transport",
      order = "a[train-system]-z[vehicle-wagon]",
      place_result = name,
      stack_size = 1
    }
end
