local logic = {}
local cachedTotals = {}

-- Helper to identify Potion type via NBT/Components
function logic.getPotionType(detail)
    if not detail or detail.name ~= "minecraft:potion" then return "not_a_potion" end
    local p = (detail.components and detail.components["minecraft:potion_contents"] and detail.components["minecraft:potion_contents"].type) or
              (detail.nbt and detail.nbt.Potion)
    return p or "minecraft:water" -- Default to water if no tag exists
end

-- Update internal memory of chest contents
function logic.updateSnapshot(chest)
    local success, inventory = pcall(chest.list)
    if not success then return {}, {} end
    local totals = {}
    local realWater = 0
    local awkward = 0
    for slot, item in pairs(inventory) do
        totals[item.name] = (totals[item.name] or 0) + item.count
        if item.name == "minecraft:potion" then
            local d = chest.getItemDetail(slot)
            local pType = logic.getPotionType(d)
            if pType == "minecraft:water" then realWater = realWater + item.count
            elseif pType == "minecraft:awkward" then awkward = awkward + item.count end
        end
    end
    cachedTotals = totals
    cachedTotals["_water"] = realWater
    cachedTotals["_awkward"] = awkward
    return totals, inventory
end

function logic.getStock(itemName) return cachedTotals[itemName] or 0 end

function logic.findInChest(chest, itemName, reqType)
    local _, inv = logic.updateSnapshot(chest)
    for slot, item in pairs(inv) do
        if item.name == itemName then
            if reqType then
                local d = chest.getItemDetail(slot)
                if logic.getPotionType(d) == reqType then return slot end
            else return slot end
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

function logic.calculateMaxBrews(potionName, recipes)
    local plan = logic.getBrewingPlan(potionName, recipes)
    if not plan or #plan == 0 then return 0 end
    -- INSTANT calculation using cached counts
    local startBottles = logic.getStock("_water") + logic.getStock("minecraft:glass_bottle")
    local m = math.floor(startBottles / 3)
    for _, step in ipairs(plan) do m = math.min(m, logic.getStock(step.name)) end
    return m
end

function logic.fillWaterBottles(chest, tName)
    local empty = logic.findInChest(chest, "minecraft:glass_bottle")
    if empty then
        chest.pushItems(tName, empty, 16, 1)
        turtle.select(1)
        for i=1, 16 do if turtle.placeDown() then os.sleep(0.1) end end
    end
end

function logic.manageFuel(chest, stand)
    local p = logic.findInChest(chest, "minecraft:blaze_powder")
    if p then
        local fuel = stand.getItemDetail(5)
        if not fuel or fuel.count < 10 then chest.pushItems(peripheral.getName(stand), p, 5, 5) end
    end
end

function logic.craftBlazePowder(chest, tName)
    local rSlot = logic.findInChest(chest, "minecraft:blaze_rod")
    if rSlot then
        chest.pushItems(tName, rSlot, 1, 1)
        turtle.select(1)
        return turtle.craft()
    end
end

function logic.craftBottles(chest, tName)
    local gSlot = logic.findInChest(chest, "minecraft:glass")
    if gSlot and logic.getStock("minecraft:glass") >= 3 then
        chest.pushItems(tName, gSlot, 1, 1)
        chest.pushItems(tName, gSlot, 1, 3)
        chest.pushItems(tName, gSlot, 1, 6)
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
