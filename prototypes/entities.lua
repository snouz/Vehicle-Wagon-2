--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: entities.lua
 * Description:  Add entity prototypes for vanilla vehicles.
 *   Entities added:
 *    - Vehicle Wagon (empty)
 *    - Loaded Vehicle Wagon (Car)
 *    - Loaded Vehicle Wagon (Tank)
 *    - Loaded Vehicle Wagon (Tarp)
--]]

local base_wagon_layer = {
  size = 256,
  direction_count = 128,
  filenames = {
    "__VehicleWagon2__/graphics/entity/base_wagon/cargo_fb_sheet.png",
    "__VehicleWagon2__/graphics/entity/base_wagon/cargo_fb_sheet.png"
  },
  line_length = 8,
  lines_per_file = 8,
  shift = util.by_pixel(13, -38),
  hr_version = {
    size = 512,
    scale = 0.5,
    direction_count = 128,
    filenames = {
      "__VehicleWagon2__/graphics/entity/base_wagon/hr-cargo_fb_sheet.png",
      "__VehicleWagon2__/graphics/entity/base_wagon/hr-cargo_fb_sheet.png"
    },
    line_length = 8,
    lines_per_file = 8,
    shift = util.by_pixel(13, -38.5),
  }
}

local base_wagon_layer_shadow = {
  size = 256,
  direction_count = 128,
  filenames = {
    "__VehicleWagon2__/graphics/entity/base_wagon/cargo_fb_sheet-shadow.png",
    "__VehicleWagon2__/graphics/entity/base_wagon/cargo_fb_sheet-shadow.png"
  },
  line_length = 8,
  lines_per_file = 8,
  shift = util.by_pixel(13, -38),
  draw_as_shadow = true,
  hr_version = {
    size = 512,
    scale = 0.5,
    direction_count = 128,
    filenames = {
      "__VehicleWagon2__/graphics/entity/base_wagon/hr-cargo_fb_sheet-shadow.png",
      "__VehicleWagon2__/graphics/entity/base_wagon/hr-cargo_fb_sheet-shadow.png"
    },
    line_length = 8,
    lines_per_file = 8,
    shift = util.by_pixel(13, -38.5),
    draw_as_shadow = true,
  }
}


local useWeights = settings.startup["vehicle-wagon-use-custom-weights"].value
local maxWeight = (useWeights and settings.startup["vehicle-wagon-maximum-weight"].value) or math.huge

local vehicle_wagon = util.table.deepcopy(data.raw["cargo-wagon"]["cargo-wagon"])
vehicle_wagon.name = "vehicle-wagon"
vehicle_wagon.icon = "__VehicleWagon2__/graphics/icons/vehicle-wagon-icon.png"
vehicle_wagon.icon_size = 64
vehicle_wagon.inventory_size = 0
vehicle_wagon.minable = {mining_time = 1, result = "vehicle-wagon"}
vehicle_wagon.horizontal_doors = nil
vehicle_wagon.vertical_doors = nil
vehicle_wagon.pictures =
{
	layers =
	{
		base_wagon_layer,
        base_wagon_layer_shadow,
	}
}
data:extend{vehicle_wagon}


local loaded_car = util.table.deepcopy(vehicle_wagon)
loaded_car.name = "loaded-vehicle-wagon-car"
loaded_car.pictures =
{
	layers =
	{
		base_wagon_layer,
        base_wagon_layer_shadow,
		{
			width = 114,
			height = 76,
			direction_count = 128,
			shift = {0.28125, -0.55},
			scale = 0.95,
			filenames =
			{
				"__VehicleWagon2__/graphics/entity/car/car-shadow-1.png",
				"__VehicleWagon2__/graphics/entity/car/car-shadow-2.png",
				"__VehicleWagon2__/graphics/entity/car/car-shadow-3.png"
			},
			line_length = 2,
			lines_per_file = 22,
		},
		{
			width = 102,
			height = 86,
			direction_count = 128,
			shift = {0, -0.9875},
			scale = 0.95,
			filenames =
			{
				"__base__/graphics/entity/car/car-1.png",
				"__base__/graphics/entity/car/car-2.png",
				"__base__/graphics/entity/car/car-3.png",
			},
			line_length = 2,
			lines_per_file = 22,
		},
		{
			width = 36,
			height = 29,
			direction_count = 128,
			shift = {0.03125, -1.690625},
			scale = 0.95,
			filenames =
			{
				"__VehicleWagon2__/graphics/entity/car/turret.png",
			},
			line_length = 2,
			lines_per_file = 64,
		}
	}
}

local loaded_tarp = util.table.deepcopy(vehicle_wagon)
loaded_tarp.name = "loaded-vehicle-wagon-tarp"
loaded_tarp.pictures =
{
	layers =
	{
		base_wagon_layer,
        base_wagon_layer_shadow,
		{
			width = 192,
			height = 192,
			direction_count = 128,
			shift = {0, -0.5},
			scale = 0.95,
			filenames =
			{
				"__VehicleWagon2__/graphics/entity/tarp/tarp-shadow.png",
				"__VehicleWagon2__/graphics/entity/tarp/tarp-shadow.png",
			},
			line_length = 8,
			lines_per_file = 8,
		},
		{
			width = 192,
			height = 192,
			direction_count = 128,
			shift = {0, -0.5},
			scale = 0.95,
			filenames =
			{
				"__VehicleWagon2__/graphics/entity/tarp/tarp.png",
				"__VehicleWagon2__/graphics/entity/tarp/tarp.png",
			},
			line_length = 8,
			lines_per_file = 8,
		}
	}
}


local loaded_tank = util.table.deepcopy(vehicle_wagon)
loaded_tank.name = "loaded-vehicle-wagon-tank"
loaded_tank.pictures =
{
	layers =
	{
		base_wagon_layer,
        base_wagon_layer_shadow,
		{
			width = 154,
			height = 99,
			direction_count = 128,
			shift = {0.69375, -0.571875},
			scale = 0.95,
			filenames =
			{
				"__VehicleWagon2__/graphics/entity/tank/base-shadow-1.png",
				"__VehicleWagon2__/graphics/entity/tank/base-shadow-2.png",
				"__VehicleWagon2__/graphics/entity/tank/base-shadow-3.png",
				"__VehicleWagon2__/graphics/entity/tank/base-shadow-4.png"
			},
			line_length = 2,
			lines_per_file = 16,
		},
		{
			width = 139,
			height = 110,
			direction_count = 128,
			shift = {-0.040625, -1.18125},
			scale = 0.95,
			filenames =
			{
				"__VehicleWagon2__/graphics/entity/tank/base-1.png",
				"__VehicleWagon2__/graphics/entity/tank/base-2.png",
				"__VehicleWagon2__/graphics/entity/tank/base-3.png",
				"__VehicleWagon2__/graphics/entity/tank/base-4.png"
			},
			line_length = 2,
			lines_per_file = 16,
		},
		{
			width = 92,
			height = 69,
			direction_count = 128,
			shift = {-0.05625, -1.97812},
			scale = 0.95,
			filenames =
			{
				"__VehicleWagon2__/graphics/entity/tank/turret-1.png",
				"__VehicleWagon2__/graphics/entity/tank/turret-2.png",
				"__VehicleWagon2__/graphics/entity/tank/turret-3.png",
				"__VehicleWagon2__/graphics/entity/tank/turret-4.png"
			},
			line_length = 2,
			lines_per_file = 16,
		}
	}
}
-- Car, Tank, and Tarp need to be loaded regardless of weight limit
data:extend{loaded_car, makeDummyItem(loaded_car.name),
            loaded_tank, makeDummyItem(loaded_tank.name),
            loaded_tarp, makeDummyItem(loaded_tarp.name)}

