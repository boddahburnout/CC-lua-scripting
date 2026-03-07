local logic = {}
local cachedTotals = {}

-- 1. IDENTIFICATION: Stronger NBT/Component Detection
function logic.getPotionType(detail)
    if not detail or detail.name ~= "minecraft:potion" then return "not_a_potion" end
    -- Check for 1.20.5+ Components or older NBT tags
    local p = (detail.components and detail.components["minecraft:potion_contents"] and detail.components["minecraft:potion_contents"].type) or
              (detail.nbt and detail.nbt.Potion)
    
    return p or "minecraft:water" -- Default to water
end

-- 2. RESET: Clear the Stand entirely to prevent jams
function logic.purgeStand(stand, tName, chest)
    -- Pull everything from the stand's 5 slots (Bottles, Ingredient, Fuel)
    for s = 1, 5 do
        stand.pushItems(tName, s, 64)
    end
    -- Immediately dump those items from Turtle to Chest to keep Turtle empty
    for i = 1, 16 do
        if turtle.getItemCount(i) > 0 then
            turtle.select(i)
            chest.pullItems(tName, i)
        end
    end
end

-- 3. SNAPSHOT: Deep-scan with bucket separation
function logic.updateSnapshot(chest)
    local success, inventory = pcall(chest.list)
    if not success then return {}, {} end
    local totals, realWater, awkward = {}, 0, 0
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

-- 4. SEARCH: Strict NBT matching for Water vs Awkward
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

-- 5. BREWING LOGIC
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
    if potionName == "awkward" then return 0 end
    local plan = logic.getBrewingPlan(potionName, recipes)
    if not plan or #plan == 0 then return 0 end
    
    local startBottles = logic.getStock("_water") + logic.getStock("minecraft:glass_bottle") + logic.getStock("_awkward")
    local m = math.floor(startBottles / 3)
    
    for _, step in ipairs(plan) do
        if not (step.name == "minecraft:nether_wart" and logic.getStock("_awkward") >= 3) then
            m = math.min(m, logic.getStock(step.name))
        end
    end
    return m
end

-- 6. MAINTENANCE
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
        local f = stand.getItemDetail(5)
        if not f or f.count < 10 then chest.pushItems(peripheral.getName(stand), p, 5, 5) end
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
