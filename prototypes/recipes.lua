--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: recipes.lua
 * Description:  Add recipe prototypes.
 *   Recipes added:
 *    - Vehicle Wagon (empty)
 *    - Winch (capsule)
 *    - Loading Ramp
--]]


data:extend{
  {
    type = "recipe",
    name = "vehicle-wagon",
    enabled = "false",
    ingredients =
    {
      {"iron-gear-wheel", 10},
      {"iron-stick", 20},
      {"steel-plate", 30}
    },
    result = "vehicle-wagon"
  },
  {
    type = "recipe",
    name = "winch",
    enabled = "false",
    ingredients =
    {
      {"engine-unit", 1},
      {"iron-gear-wheel", 5},
      {"iron-plate", 5},
    },
    result_count = 1,
    result = "winch"
  },
  {
    type = "recipe",
    name = "loading-ramp",
    enabled = "false",
    ingredients =
    {
      {"stone-brick", 10},
      {"steel-plate", 5},
      {"iron-plate", 10},
    },
    result_count = 1,
    result = "loading-ramp"
  }
}
