local recipes = require("recipes")
local logic = require("logic")
local ui = require("ui")

local chest = peripheral.find("minecraft:chest")
local stand = peripheral.find("minecraft:brewing_stand")
local modem = peripheral.find("modem")
local tName = modem and modem.getNameLocal() or "turtle"
local isBrewing = false

-- Forward declarations to handle circular menu calls
local mainMenu, craftableMenu, missingMenu, statusScreen, adminMenu

-----------------------------------------------------------
-- 1. THE REFINED BREWING ENGINE (No-Jam Version)
-----------------------------------------------------------
local function executeBrew(name, amt, silent)
    isBrewing = true
    local plan = logic.getBrewingPlan(name, recipes)
    
    for b = 1, amt do
        if not silent then
            term.clear()
            term.setCursorPos(1, 2)
            term.setTextColor(colors.yellow)
            print("-- ORDER: " .. name:upper() .. " (" .. b .. "/" .. amt .. ") --")
            term.setTextColor(colors.white)
        end

        -- A. THE PURGE: Clear Stand and Turtle completely
        if not silent then print("Purging hardware...") end
        logic.purgeStand(stand, tName, chest)
        
        -- B. THE IDENTITY LOCK: Determine if we use Water or pre-made Awkward
        -- If making awkward, we MUST use Water. If making others, check stock.
        local hasAwkward = (logic.getStock("_awkward") >= 3 and name ~= "awkward")
        local startType = hasAwkward and "minecraft:awkward" or "minecraft:water"
        
        -- C. LOAD BOTTLES: Using the Strict NBT findInChest from logic.lua
        for s = 1, 3 do 
            local bSlot = logic.findInChest(chest, "minecraft:potion", startType)
            if bSlot then 
                chest.pushItems(peripheral.getName(stand), bSlot, 1, s) 
            end
        end

        -- D. ADD INGREDIENTS: Follow the recipe plan
        for _, step in ipairs(plan) do
            -- Skip Nether Wart if we already loaded Awkward Potions
            if not (startType == "minecraft:awkward" and step.name == "minecraft:nether_wart") then
                local ing = logic.findInChest(chest, step.name)
                if ing then 
                    if not silent then print(" + Adding " .. step.name) end
                    chest.pushItems(peripheral.getName(stand), ing, 1, 4)
                    os.sleep(22) -- Wait for brew
                end
            end
        end
        
        -- E. AUTO-STORAGE: Move results directly to chest
        if not silent then print("Storing results...") end
        for s = 1, 3 do stand.pushItems(tName, s, 1) end
        for i = 1, 16 do 
            if turtle.getItemCount(i) > 0 then chest.pullItems(tName, i) end 
        end
    end
    
    isBrewing = false
    if not silent then mainMenu() end
end

-----------------------------------------------------------
-- 2. UI MENUS (Scrollable & Safe)
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
        { text = "BACK", handler = function() craftableMenu() end }
    }
    ui.new(name:upper() .. " (MAX: "..max..")", items):run()
end

function craftableMenu()
    local items = {}
    local names = {}
    -- Filter out Awkward from the UI
    for n in pairs(recipes) do if n ~= "awkward" then table.insert(names, n) end end
    table.sort(names)

    for _, n in ipairs(names) do
        local m = logic.calculateMaxBrews(n, recipes)
        if m > 0 then
            table.insert(items, { 
                text = n:upper() .. " (" .. m .. ")", 
                handler = function() brewQuantityMenu(n) end 
            })
        end
    end
    table.insert(items, { text = "BACK", handler = function() mainMenu() end })
    ui.new("CRAFTABLE", items):run()
end

local function showMissingDetails(name)
    term.clear()
    term.setCursorPos(1, 2)
    print("RECIPE: " .. name:upper())
    local plan = logic.getBrewingPlan(name, recipes)
    for _, step in ipairs(plan) do
        local c = logic.getStock(step.name)
        term.setTextColor(c == 0 and colors.red or colors.green)
        print(" [" .. (c == 0 and "X" or "OK") .. "] " .. step.name)
    end
    term.setTextColor(colors.white)
    print("\nPress any key...")
    os.pullEvent("key")
    missingMenu()
end

function missingMenu()
    local items = {}
    for n, _ in pairs(recipes) do
        if n ~= "awkward" and logic.calculateMaxBrews(n, recipes) == 0 then
            table.insert(items, { text = n:upper(), handler = function() showMissingDetails(n) end })
        end
    end
    table.insert(items, { text = "BACK", handler = function() mainMenu() end })
    ui.new("UNCRAFTABLE", items):run()
end

function statusScreen()
    term.clear()
    term.setCursorPos(1, 2)
    term.setTextColor(colors.yellow)
    print("-- SYSTEM STATUS --")
    term.setTextColor(colors.white)
    print("Water:    " .. logic.getStock("_water"))
    print("Awkward:  " .. logic.getStock("_awkward"))
    print("Fuel:     " .. logic.getStock("minecraft:blaze_powder"))
    print("\nPress any key to return...")
    os.pullEvent("key")
    mainMenu()
end

function adminMenu()
    local items = {
        { text = "GLOBAL EJECT", handler = function() 
            logic.globalEject(chest, stand, tName) 
            mainMenu() 
        end },
        { text = "BACK", handler = function() mainMenu() end }
    }
    ui.new("ADMIN TOOLS", items):run()
end

function mainMenu()
    local items = {
        { text = "BREW", handler = function() craftableMenu() end },
        { text = "MISSING", handler = function() missingMenu() end },
        { text = "STATUS", handler = function() statusScreen() end },
        { text = "ADMIN TOOLS", handler = function() adminMenu() end }
    }
    ui.new("ALCH-OS v3.7", items):run()
end

-----------------------------------------------------------
-- 3. BACKGROUND WORKER (Auto-Stocking & Maintenance)
-----------------------------------------------------------
local function backgroundWorker()
    while true do
        logic.updateSnapshot(chest)
        if not isBrewing then
            -- A. AUTO-STOCK AWKWARD POTIONS (< 15)
            if logic.getStock("_awkward") < 15 then
                local can = logic.getStock("minecraft:nether_wart") > 0 and 
                            (logic.getStock("_water") + logic.getStock("minecraft:glass_bottle")) >= 3
                if can then executeBrew("awkward", 1, true) end
            end

            -- B. PHYSICAL MAINTENANCE
            logic.fillWaterBottles(chest, tName)
            logic.manageFuel(chest, stand)
            if logic.getStock("minecraft:blaze_powder") < 5 then logic.craftBlazePowder(chest, tName) end
            if logic.getStock("minecraft:glass_bottle") < 6 then logic.craftBottles(chest, tName) end
            
            -- C. INVENTORY SORTING
            local keepers = {["minecraft:potion"]=true, ["minecraft:glass_bottle"]=true, ["minecraft:blaze_powder"]=true, ["minecraft:nether_wart"]=true, ["minecraft:glass"]=true, ["minecraft:blaze_rod"]=true}
            for _, r in pairs(recipes) do keepers[r.ingredient] = true end
            for i=1, 16 do
                local itm = turtle.getItemDetail(i)
                if itm then
                    if keepers[itm.name] then chest.pullItems(tName, i) 
                    else turtle.select(i) turtle.dropDown() end
                end
            end
        end
        os.sleep(5)
    end
end

-----------------------------------------------------------
-- 4. BOOT ORCHESTRATOR
-----------------------------------------------------------
parallel.waitForAny(backgroundWorker, function()
    while true do mainMenu() end
end)
