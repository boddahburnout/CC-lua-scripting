local logic = {}
local cachedTotals = {}

function logic.getPotionType(detail)
    if not detail or detail.name ~= "minecraft:potion" then return "not_a_potion" end
    local name = detail.displayName or ""
    if name == "Water Bottle" then return "water" end
    if name == "Awkward Potion" then return "awkward" end
    return "final_potion"
end

function logic.purgeStand(stand, tName, chest)
    for s = 1, 5 do stand.pushItems(tName, s, 64) end
    for i = 1, 16 do
        local d = turtle.getItemDetail(i)
        if d and logic.getPotionType(d) == "awkward" then
            turtle.select(i)
            chest.pullItems(tName, i)
        end
    end
end

-- NEW: Targeted Cleanup (Background Safe)
function logic.cleanupInventory(chest, tName, recipes)
    local k = {["minecraft:glass_bottle"]=true, ["minecraft:blaze_powder"]=true, ["minecraft:nether_wart"]=true, ["minecraft:glass"]=true, ["minecraft:blaze_rod"]=true}
    for _, r in pairs(recipes) do k[r.ingredient] = true end
    
    for i = 1, 16 do
        local itm = turtle.getItemDetail(i)
        if itm then
            local pType = logic.getPotionType(itm)
            -- MOVE IF: Utility item OR specifically an Awkward potion
            if k[itm.name] or pType == "awkward" then
                turtle.select(i)
                chest.pullItems(tName, i)
            -- REJECT IF: Pure junk (Not a potion and not a keeper)
            elseif pType == "not_a_potion" and not k[itm.name] then
                turtle.select(i)
                turtle.dropDown()
            end
            -- FINAL POTIONS (Strength, Invis, etc) are strictly IGNORED
        end
    end
end

function logic.updateSnapshot(chest)
    local success, inventory = pcall(chest.list)
    if not success then return {}, {} end
    local totals, water, awkward = {}, 0, 0
    for slot, item in pairs(inventory) do
        totals[item.name] = (totals[item.name] or 0) + item.count
        if item.name == "minecraft:potion" then
            local d = chest.getItemDetail(slot)
            local pType = logic.getPotionType(d)
            if pType == "water" then water = water + item.count
            elseif pType == "awkward" then awkward = awkward + item.count end
        end
    end
    cachedTotals = totals
    cachedTotals["_water"] = water
    cachedTotals["_awkward"] = awkward
    return totals, inventory
end

function logic.getStock(itemName) return cachedTotals[itemName] or 0 end

function logic.findInChest(chest, itemName, reqType)
    local success, inv = pcall(chest.list)
    if not success then return nil end
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

function logic.displayStatus(mon, recipes)
    if not mon then return end
    mon.clear()
    local w, h = mon.getSize()
    local mid = math.floor(w / 2)
    mon.setCursorPos(1, 1)
    mon.setTextColor(colors.yellow)
    mon.write("STOCK")
    mon.setCursorPos(mid + 2, 1)
    mon.write("MISSING")
    mon.setTextColor(colors.gray)
    for y = 1, h do mon.setCursorPos(mid + 1, y) mon.write("|") end
    mon.setTextColor(colors.white)
    local essentials = {["Water"]="_water", ["Awkward"]="_awkward", ["Fuel"]="minecraft:blaze_powder", ["Wart"]="minecraft:nether_wart"}
    local y = 3
    for label, key in pairs(essentials) do
        mon.setCursorPos(2, y)
        mon.write(label .. ": " .. logic.getStock(key))
        y = y + 1
    end
    mon.setTextColor(colors.red)
    y = 3
    local seen = {}
    for _, r in pairs(recipes) do
        if not seen[r.ingredient] and logic.getStock(r.ingredient) == 0 then
            if y < h then
                mon.setCursorPos(mid + 3, y)
                local shortName = r.ingredient:gsub("minecraft:", "")
                mon.write("- " .. shortName:sub(1, mid - 4))
                y = y + 1
                seen[r.ingredient] = true
            end
        end
    end
end

function logic.fillWaterBottles(chest, tName)
    if logic.getStock("_water") >= 20 then return end 
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
