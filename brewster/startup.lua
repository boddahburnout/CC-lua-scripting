local recipes = require("recipes")
local logic = require("logic")
local ui = require("ui")

local chest = peripheral.find("minecraft:chest")
local stand = peripheral.find("minecraft:brewing_stand")
local modem = peripheral.find("modem")
local tName = modem and modem.getNameLocal() or "turtle"
local isBrewing = false

local mainMenu

-----------------------------------------------------------
-- ENGINE: Hard-Reset & Smart Brewing
-----------------------------------------------------------
local function executeBrew(name, amt, silent)
    isBrewing = true
    local plan = logic.getBrewingPlan(name, recipes)
    
    for b = 1, amt do
        if not silent then
            ui.drawHeader("ORDER: " .. name:upper())
            print("Batch " .. b .. "/" .. amt)
        end

        -- 1. HARD RESET: Scan and Clear Stand and Turtle
        if not silent then print("Purging Stand/Turtle...") end
        -- Clear Stand Slots 1-5 (Bottles, Ingredients, and Fuel)
        for s = 1, 5 do
            stand.pushItems(tName, s, 64)
        end
        -- Dump Turtle inventory into Chest
        for i = 1, 16 do
            if turtle.getItemCount(i) > 0 then
                turtle.select(i)
                chest.pullItems(tName, i)
            end
        end

        -- 2. Determine Base
        -- If brewing "awkward", we MUST use water. 
        -- If brewing others, check if we have pre-brewed Awkward in stock.
        local hasAwkward = logic.getStock("_awkward") >= 3
        local startType = (hasAwkward and name ~= "awkward") and "minecraft:awkward" or "minecraft:water"
        
        -- 3. Load Bottles (Strict Search)
        for s = 1, 3 do 
            local bSlot = logic.findInChest(chest, "minecraft:potion", startType)
            if bSlot then 
                chest.pushItems(peripheral.getName(stand), bSlot, 1, s) 
            end
        end

        -- 4. Follow Plan
        for _, step in ipairs(plan) do
            -- Skip Nether Wart if we loaded Awkward bottles
            if not (startType == "minecraft:awkward" and step.name == "minecraft:nether_wart") then
                local ing = logic.findInChest(chest, step.name)
                if ing then 
                    if not silent then print(" + Adding " .. step.name) end
                    chest.pushItems(peripheral.getName(stand), ing, 1, 4)
                    os.sleep(22)
                end
            end
        end
        
        -- 5. AUTO-STORAGE: Move results directly to storage chest
        if not silent then print("Storing results...") end
        for s = 1, 3 do
            stand.pushItems(tName, s, 1) -- To Turtle
        end
        for i = 1, 16 do
            chest.pullItems(tName, i) -- To Chest
        end
    end
    
    isBrewing = false
    if not silent then mainMenu() end
end

-----------------------------------------------------------
-- UI MENUS (Same as before, calling new executeBrew)
-----------------------------------------------------------
local function brewQuantityMenu(name)
    local max = logic.calculateMaxBrews(name, recipes)
    local items = {
        { text = "START BREW", handler = function()
            term.clear()
            term.setCursorPos(1, 2)
            print("Enter quantity (Max " .. max .. "):")
            local q = tonumber(read())
            if q and q > 0 and q <= max then executeBrew(name, q) else mainMenu() end
        end},
        { text = "BACK", handler = mainMenu }
    }
    ui.new(name:upper() .. " (MAX: "..max..")", items):run()
end

-- ... [Other menu functions remain the same as ALCH-OS v3.6] ...

function mainMenu()
    local items = {
        { text = "BREW", handler = craftableMenu },
        { text = "MISSING", handler = missingMenu },
        { text = "STATUS", handler = statusScreen },
        { text = "ADMIN TOOLS", handler = adminMenu }
    }
    ui.new("ALCH-OS v3.7", items):run()
end

-----------------------------------------------------------
-- BACKGROUND TASKS (Including the Purge and Refuel)
-----------------------------------------------------------
local function backgroundWorker()
    while true do
        logic.updateSnapshot(chest)
        if not isBrewing then
            -- 1. Auto-Stock Awkward Potions (< 15)
            if logic.getStock("_awkward") < 15 then
                local can = logic.getStock("minecraft:nether_wart") > 0 and 
                            (logic.getStock("_water") + logic.getStock("minecraft:glass_bottle")) >= 3
                if can then executeBrew("awkward", 1, true) end
            end

            -- 2. Maintenance
            logic.fillWaterBottles(chest, tName)
            logic.manageFuel(chest, stand)
            if logic.getStock("minecraft:blaze_powder") < 5 then logic.craftBlazePowder(chest, tName) end
            if logic.getStock("minecraft:glass_bottle") < 6 then logic.craftBottles(chest, tName) end
            
            -- 3. Sorter (Dump unwanted turtle items)
            local keepers = {["minecraft:potion"]=true, ["minecraft:glass_bottle"]=true, ["minecraft:blaze_powder"]=true, ["minecraft:nether_wart"]=true, ["minecraft:glass"]=true, ["minecraft:blaze_rod"]=true}
            for _, r in pairs(recipes) do keepers[r.ingredient] = true end
            for i=1, 16 do
                local itm = turtle.getItemDetail(i)
                if itm and not keepers[itm.name] then 
                    turtle.select(i) 
                    turtle.dropDown() 
                elseif itm then
                    chest.pullItems(tName, i)
                end
            end
        end
        os.sleep(5)
    end
end

parallel.waitForAny(backgroundWorker, function()
    while true do mainMenu() end
end)
