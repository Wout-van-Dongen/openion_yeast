-- TODO Add option to reduce culture health when lacking feed
-- TODO Clean code

-- Mod container ---------------------------------------------------------------
openion_yeast = {}

-- Properties
local yeast_doubling_time = (minetest.settings:get("openion_yeast_doubling_time") or 90) * 60 / (minetest.settings:get("time_speed") or 72) -- doubling time in real-life seconds
local moist_level_per_bucket = minetest.settings:get("openion_yeast_water_per_bucket") or 100
local max_moist_level = (minetest.settings:get("openion_yeast_max_water_level") or 3) * moist_level_per_bucket
local bottle_capacity = minetest.settings:get("openion_yeast_yeast_per_bottle") or 5
local bottle_fill_time = (minetest.settings:get("openion_yeast_bottle_fill_speed") or 12) / (minetest.settings:get("time_speed") or 72) -- time for one bottle to fill in real-life seconds
local yeast_starvation = minetest.settings:get("openion_yeast_yeast_starvation") or false
local expected_yeast = minetest.settings:get("openion_yeast_yeast_production") or 1
local required_water = minetest.settings:get("openion_yeast_water_cost") or 1
local required_carrier = minetest.settings:get("openion_yeast_carrier_cost") or 1
local required_vessel = minetest.settings:get("openion_yeast_vessel_cost") or 1
local required_feed = minetest.settings:get("openion_yeast_feed_cost") or 5

-- Yeast Ingredients & Result --------------------------------------------------

-- Collections
local ItemCollection = {}
setmetatable(ItemCollection, { __index = table })
function ItemCollection:new()
    local t = {}
    setmetatable(t, { __index=self })
    return t
end
function ItemCollection:register(itemname)
    self:insert(itemname)
end
function ItemCollection:is_registered(itemname)
    for key, value in pairs(self) do
        if value == itemname then
            return true
        end
    end
    return false
end

openion_yeast.yeast_output = "openion_yeast:bottle_of_yeast"
openion_yeast.yeast_carriers = ItemCollection:new()
openion_yeast.yeast_feeds = ItemCollection:new()
openion_yeast.yeast_moists = ItemCollection:new()
openion_yeast.yeast_vessels = ItemCollection:new()

-- Yeast carriers --------------------------------------------------------------
if(minetest.get_modpath("farming") ~= nil) then
    openion_yeast.yeast_carriers:register("farming:wheat")
    openion_yeast.yeast_carriers:register("farming:barley")
    openion_yeast.yeast_carriers:register("farming:oat")
    openion_yeast.yeast_carriers:register("farming:rye")
end

-- Yeast Feeds -------------------------------------------------------
if(minetest.get_modpath("farming") ~= nil) then
    openion_yeast.yeast_feeds:register("farming:sugar")
end

-- Yeast Moist -------------------------------------------------------
openion_yeast.yeast_moists:register("bucket:bucket_water")
openion_yeast.yeast_carriers:register("bucket:bucket_river_water")

-- Yeast Vessels -----------------------------------------------------
openion_yeast.yeast_vessels:register("vessels:glass_bottle");

-- FormSpec -----------------------------------------------------------
openion_yeast.formspec = [[
	size[10,10]
    padding[0,0]
    item_image[0,0;1,1;openion_yeast:yeast_barrel]
    label[1,.3;Yeast Barrel]
    image[1,1;1,1;farming_sugar.png^[colorize:#555555]
    image[1,2;1,1;farming_wheat.png^[colorize:#555555]
    image[1,3;1,1;bucket_water.png^[colorize:#555555]
    image[5,4;1,1;vessels_glass_bottle.png^[colorize:#555555]
	list[context;feed;1,1;1,1;]
	list[context;water;1,3;1,1;]
	list[context;carrier;1,2;1,1;]
	list[context;yeast;8,1;1,4;]
	list[context;vessels;5,4;1,1;]
    item_image[1, 4;1,1;openion_yeast:bottle_of_yeast]
	list[current_player;main;1,6;8,4]
    image[2,3.5;2.2,.3;openion_yeast_empty_bar.png]
    image[2,4.5;2.2,.3;openion_yeast_empty_bar.png]
    label[2,1;feed]
    label[2,2;carrier]
    label[2,3;water]
    label[2,4;yeast]
    label[6,4;vessels]
]]

-- Methods
local function allow_dig(position, player)
	if minetest.is_protected(position, player:get_player_name()) then
		minetest.chat_send_player(player:get_player_name(), "This barrel is not yours to remove")
		return false
	end
	local meta = minetest.get_meta(position)
	local inventory = meta:get_inventory()
	if inventory:is_empty("feed") and inventory:is_empty("carrier") and inventory:is_empty("water") and inventory:is_empty("yeast") and inventory:is_empty("vessels") then
		return true
	else
		minetest.chat_send_player(player:get_player_name(), "The barrel is not empty!")
		return false
	end

end

local function allow_inventory_take(position, list_name, index, stack, player)
	if minetest.is_protected(position, player:get_player_name()) then
		minetest.chat_send_player(player:get_player_name(), "Are you trying to take things that are not yours?")
		return 0
	end
	if list_name == "feed" then
		return stack:get_count()
	elseif list_name == "carrier" then
		return stack:get_count()
	elseif list_name == "water" then
		return stack:get_count()
	elseif list_name == "vessels" then
		return stack:get_count()
	elseif list_name == "yeast" then
		return stack:get_count()
	end
	return 0
end

local function allow_inventory_put(position, list_name, index, stack, player)
	if minetest.is_protected(position, player:get_player_name()) then
		minetest.chat_send_player(player:get_player_name(), "Let's leave this dangerous operation to authorized personal, shall we?")
		return 0
	end
	if list_name == "feed" and openion_yeast.yeast_feeds:is_registered(stack:get_name()) then
		return stack:get_count()
	elseif list_name == "carrier" and openion_yeast.yeast_carriers:is_registered(stack:get_name()) then
		return stack:get_count()
	elseif list_name == "water" and openion_yeast.yeast_moists:is_registered(stack:get_name()) then
		return stack:get_count()
	elseif list_name == "vessels" and  openion_yeast.yeast_vessels:is_registered(stack:get_name()) then
		return stack:get_count()
	end
	return 0
end

local function allow_inventory_move(position, source_list, source_index, target_list, target_index, count, player)
	local meta = minetest.get_meta(position)
	local inventory = meta:get_inventory()
	local source_stack  = inventory:get_stack(source_list, source_index)
	return openion_yeast.allow_inventory_put(position, target_list, target_index, source_stack, player)
end

local function construct(position, player)
	local meta = minetest.get_meta(position)
	local inventory = meta:get_inventory()

	-- Set up inventory
	inventory:set_size("feed", 1)
	inventory:set_size("carrier", 1)
	inventory:set_size("water", 1)
	inventory:set_size("vessels", 1)
	inventory:set_size("yeast", 4)

	-- Set up container values
	meta:set_float("yeast", 0)
	meta:set_float("moist", 0)

	-- Add Formspec
	meta:set_string("formspec", openion_yeast:get_formspec())

	-- Activate timer (temporarily - for testing purposes)
	local timer = minetest.get_node_timer(position)
    --timer:start(5)
end

local function update(position, elapsed)
	local time_speed = minetest.settings:get("time_speed") or 72
	local meta = minetest.get_meta(position)
    local inventory = meta:get_inventory()
	local yeast_update_time = meta:get_float("yeast_update_time") or 0
	local yeast_level = meta:get_float("yeast_level") or 0
	local moist_level = meta:get_float("moist_level") or 0
	local bottle_update_time = meta:get_float("bottle_update_time") or 0

    -- fill water tank
    if moist_level <= max_moist_level - moist_level_per_bucket then
        for i = 1, #openion_yeast.yeast_moists do
            local required_stack = ItemStack({name = openion_yeast.yeast_moists[i], count = required_water})

            if(inventory:contains_item("water", required_stack, false)) then
                inventory:remove_item("water", required_stack)
                if(string.match(required_stack:get_name(), '^bucket:*')) then
                    inventory:add_item("water", ItemStack({name = "bucket:bucket_empty", count = 1}))
                end
                moist_level = moist_level + 100
                break
            end
        end
    end

    if moist_level > 0 then
        -- add in the carrier culture when moist
        if yeast_level == 0 then
            --reset the timer
            yeast_update_time = 0
            for i = 1, #openion_yeast.yeast_carriers do
                local required_stack = ItemStack({name = openion_yeast.yeast_carriers[i], count = required_carrier})

                if(inventory:contains_item("carrier", required_stack, false)) then
                    inventory:remove_item("carrier", required_stack)
                    yeast_level = 1
                    break
                end
            end
        elseif yeast_level > 0 then
            yeast_update_time = yeast_update_time + elapsed
        end
    else
        -- Stop the timer if there is no water available
        minetest.get_node_timer(position):stop()
    end

    while yeast_update_time > yeast_doubling_time and yeast_level < moist_level do
        local doubled = false
    -- double yeast concentration
        for i = 1, #openion_yeast.yeast_feeds do
            local required_stack = ItemStack({name = openion_yeast.yeast_feeds[i], count = required_feed})

            if(inventory:contains_item("feed", required_stack, false)) then
                inventory:remove_item("feed", required_stack)
                yeast_level = math.min(yeast_level * 2, moist_level)
                doubled = true
                break
            end
        end

        -- update time
        yeast_update_time = yeast_update_time - yeast_doubling_time
    end

    -- filling bottles if concentration is high enough and there's enough space in output
    while bottle_fill_time < yeast_update_time and yeast_level >= bottle_capacity and yeast_level == moist_level and inventory:room_for_item("yeast", resulting_yeast_stack) do
        local resulting_yeast_stack = ItemStack({name = openion_yeast.yeast_output, count = expected_yeast})
        for i = 1, #openion_yeast.yeast_vessels do
            local required_stack = ItemStack({name = openion_yeast.yeast_vessels[i], count = required_vessel})

            if(inventory:contains_item("vessels", required_stack, false)) then
                inventory:remove_item("vessels", required_stack)
                yeast_level = yeast_level - bottle_capacity
                moist_level = moist_level - bottle_capacity
                inventory:add_item("yeast", resulting_yeast_stack)
                break
            end
        end
        yeast_update_time = yeast_update_time - bottle_fill_time
    end

	-- Create strings for the formspec labels and progress bars
	local yeast_progress_bar = "image[2, 4.5;" .. yeast_level * 2.2 / max_moist_level .. ", .3;openion_yeast_yeast_bar.png]"
	local moist_progress_bar = "image[2, 3.5;" .. moist_level * 2.2 / max_moist_level .. ", .3;openion_yeast_water_bar.png]"

	-- Update formspec
    meta:set_string("formspec", openion_yeast.formspec .. yeast_progress_bar .. moist_progress_bar)

    -- Update Meta-data
    meta:set_float("yeast_update_time", yeast_update_time)
    meta:set_float("yeast_level", yeast_level)
    meta:set_float("moist_level", moist_level)

	return true
end

local function inventory_move(position, from_list, from_index, to_list, to_index, count, player)
    -- Start timer
    minetest.get_node_timer(position):start(1)
end

local function inventory_put(position, listname, index, stack, player)
    -- Start timer
    minetest.get_node_timer(position):start(1)
end

local function inventory_take(position, listname, index, stack, player)
    -- Start timer
    minetest.get_node_timer(position):start(1)
end


-- Getters
function openion_yeast:get_formspec()
	return self.formspec
end

-- Register Bottle with Yeast
minetest.register_craftitem("openion_yeast:bottle_of_yeast", {
    description = "Bottle of Yeast",
    inventory_image = "openion_yeast_bottle_of_yeast.png"
})

 -- Register Yeast Barrel Node
minetest.register_node("openion_yeast:yeast_barrel",
  {
      description = "Yeast Barrel",
      paramtype2 = "facedir",
      tiles = {
        "openion_yeast_barrel_top.png",
        "openion_yeast_barrel_top.png",
        "openion_yeast_barrel_side.png",
        "openion_yeast_barrel_side.png",
        "openion_yeast_barrel_side.png",
        "openion_yeast_barrel_side.png",
      },
      groups = {cracky=2},
      legacy_facedir_simple = true,
      is_ground_content = false,
      on_construct = construct,
      on_timer = update,

      on_metadata_inventory_take = inventory_take,
      on_metadata_inventory_put = inventory_put,
      on_metadata_inventory_move = inventory_move,
      can_dig = allow_dig,
      allow_metadata_inventory_put = allow_inventory_put,
      allow_metadata_inventory_move = allow_inventory_move,
      allow_metadata_inventory_take = allow_inventory_take,
  }
)

-- Create Yeast Barrel Recipe
minetest.register_craft({
       output = "openion_yeast:yeast_barrel",
       type = "shaped",
       recipe = {
           {"group:wood", "bucket:bucket_empty", "group:wood"},
           {"group:wood", "default:steelblock", "group:wood"},
           {"group:wood", "bucket:bucket_empty", "group:wood"}
       },
   })
