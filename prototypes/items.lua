--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: items.lua
 * Description:  Add item prototypes.
 *   Items added:
 *    - Winch (capsule)
 *    - Vehicle Wagon (empty)
 *    - Loading Platform
--]]


data:extend{
  {
		type = "capsule",
		name = "winch",
		icon = "__VehicleWagon2__/graphics/winch-icon.png",
		icon_size = 64,
    mipmaps = 1,
		subgroup = "transport",
		order = "a[train-system]-w[winch]",
		stack_size = 1,
    capsule_action =
		{
			type = "throw",
      uses_stack = false,
			attack_parameters =
			{
				type = "projectile",
				ammo_category = "melee",
				cooldown = 15,
				range = CAPSULE_RANGE,
				ammo_type =
				{
					category = "melee",
					target_type = "entity",
					action =
					{
						type = "direct",
						action_delivery =
						{
							type = "instant",
							target_effects =
							{
								{
									type = "play-sound",
									sound =
									{
										{
											filename = "__VehicleWagon2__/sound/latchOn.ogg",
											volume = 0
										}
									}
								}
							}
						}
					}
				}
			}
		}
	},
	{
		type = "item-with-entity-data",
		name = "vehicle-wagon",
		icon = "__VehicleWagon2__/graphics/tech-icon.png",
		icon_size = 128,
    icon_mipmaps = 1,
		subgroup = "transport",
		order = "a[train-system]-v[vehicle-wagon]",
		place_result = "vehicle-wagon",
		stack_size = 5
	},
  {
    type = "item",
    name = "loading-platform",
    icon = "__VehicleWagon2__/graphics/tech-icon.png",
    icon_size = 128,
		subgroup = "transport",
		order = "a[train-system]-v[vehicle-wagon-platform]",
		place_result = "loading-platform",
		stack_size = 10
  },
}
