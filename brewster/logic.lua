local logic = {}
local cachedTotals = {}

-- Update internal memory of chest contents
function logic.updateSnapshot(chest)
    local success, inventory = pcall(chest.list)
    if not success then return {}, {} end
    local totals = {}
    for _, item in pairs(inventory) do
        totals[item.name] = (totals[item.name] or 0) + item.count
    end
    cachedTotals = totals
    return totals, inventory
end

function logic.getStock(itemName) return cachedTotals[itemName] or 0 end

-- Helper to identify Potion type via NBT/Components
function logic.getPotionType(detail)
    if not detail or detail.name ~= "minecraft:potion" then return "not_a_potion" end
    -- Support for 1.20.5+ Components and older NBT tags
    local p = (detail.components and detail.components["minecraft:potion_contents"] and detail.components["minecraft:potion_contents"].type) or
              (detail.nbt and detail.nbt.Potion)
    return p or "minecraft:water" -- Default to water if no tag exists
end

-- Find items, optionally filtering by Potion Type
function logic.findInChest(chest, itemName, requiredPotionType)
    local _, inv = logic.updateSnapshot(chest)
    for slot, item in pairs(inv) do
        if item.name == itemName then
            if requiredPotionType then
                local detail = chest.getItemDetail(slot)
                if logic.getPotionType(detail) == requiredPotionType then return slot end
            else
                return slot
            end
        end
    end
    return nil
end

function logic.getBrewingPlan(potionName, recipes)
    local plan, current = {}, potionName
    while current ~= "minecraft:water" do
        local step = recipes[current]
        if not step then break end
        table.insert(plan, 1, {name = step.ingredient, result = current})
        current = step.base
    end
    return plan
end

function logic.calculateMaxBrews(potionName, recipes, chest)
    local plan = logic.getBrewingPlan(potionName, recipes)
    if not plan or #plan == 0 then return 0 end
    
    -- Only count bottles that are actually Water (minecraft:water)
    local waterCount = 0
    local _, inv = logic.updateSnapshot(chest)
    for slot, item in pairs(inv) do
        if item.name == "minecraft:potion" then
            local d = chest.getItemDetail(slot)
            if logic.getPotionType(d) == "minecraft:water" then waterCount = waterCount + item.count end
        end
    end
    
    local m = math.floor((waterCount + logic.getStock("minecraft:glass_bottle")) / 3)
    for _, step in ipairs(plan) do m = math.min(m, logic.getStock(step.name)) end
    return m
end

function logic.fillWaterBottles(chest, tName)
    local emptySlot = logic.findInChest(chest, "minecraft:glass_bottle")
    if emptySlot then
        chest.pushItems(tName, emptySlot, 16, 1)
        turtle.select(1)
        for i = 1, turtle.getItemCount(1) do turtle.placeDown() end -- Fill from below
    end
end

function logic.manageFuel(chest, stand)
    local powderSlot = logic.findInChest(chest, "minecraft:blaze_powder")
    if powderSlot then
        local fuelInfo = stand.getItemDetail(5)
        if not fuelInfo or fuelInfo.count < 10 then
            chest.pushItems(peripheral.getName(stand), powderSlot, 5, 5) -- Side slot 5
        end
    end
end

function logic.craftBlazePowder(chest, tName)
    local rodSlot = logic.findInChest(chest, "minecraft:blaze_rod")
    if rodSlot then
        chest.pushItems(tName, rodSlot, 1, 1)
        turtle.select(1)
        return turtle.craft()
    end
end

function logic.craftBottles(chest, tName)
    local glassSlot = logic.findInChest(chest, "minecraft:glass")
    if glassSlot and logic.getStock("minecraft:glass") >= 3 then
        chest.pushItems(tName, glassSlot, 1, 1)
        chest.pushItems(tName, glassSlot, 1, 3)
        chest.pushItems(tName, glassSlot, 1, 6)
        return turtle.craft()
    end
end

function logic.globalEject(chest, stand, tName)
    local periphs = {chest, stand}
    for _, p in ipairs(periphs) do
        if p then
            for slot, _ in pairs(p.list()) do
                p.pushItems(tName, slot, 64, 1)
                turtle.select(1)
                turtle.dropDown()
            end
        end
    end
end

return logic
