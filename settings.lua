--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: settings.lua
 * Description: Settings to control Vehicle Wagon prototypes and operation.
--]]

data:extend({
  {
    type = "bool-setting",
    name = "vehicle-wagon-allow-robot-unloading",
    order = "aa",
    setting_type = "runtime-global",
    default_value = false,
  },
  {
    type = "bool-setting",
    name = "vehicle-wagon-use-custom-weights",
    order = "ba",
    setting_type = "startup",
    default_value = true
  },
  {
    type = "double-setting",
    name = "vehicle-wagon-empty-weight-factor",
    order = "bb",
    setting_type = "startup",
    default_value = 0.5,
    minimum_value = 0.1,
    maximum_value = 2.0
  },
  {
    type = "double-setting",
    name = "vehicle-wagon-vehicle-weight-factor",
    order = "bc",
    setting_type = "startup",
    default_value = 0.3,
    minimum_value = 0.01,
    maximum_value = 1.0
  },
})

if mods["GCKI"] then
  data:extend({
    {
    type = "string-setting",
    name = "vehicle-wagon-GCKI-interaction",
    order = "cc",
    setting_type = "runtime-global",
    default_value = "owner",
    allowed_values = {"anyone","locker","owner"}
    },
  })
end
