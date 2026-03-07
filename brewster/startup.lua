local recipes = require("recipes")
local logic = require("logic")
local ui = require("ui")

local chest = peripheral.find("minecraft:chest")
local stand = peripheral.find("minecraft:brewing_stand")
local modem = peripheral.find("modem")
local tName = modem and modem.getNameLocal() or "turtle"
local isBrewing = false

-- Forward declaration so sub-menus can return to main
local mainMenu

-----------------------------------------------------------
-- CORE ENGINE: The Brewing Process
-----------------------------------------------------------
local function executeBrew(name, amt)
    isBrewing = true
    local plan = logic.getBrewingPlan(name, recipes)
    
    for b = 1, amt do
        term.clear()
        term.setCursorPos(1, 2)
        term.setTextColor(colors.yellow)
        print("-- BREWING: " .. name:upper() .. " --")
        term.setTextColor(colors.white)
        print("Batch " .. b .. " of " .. amt)
        
        -- 1. Load Water (Slots 1, 2, 3)
        for s = 1, 3 do 
            local wSlot = logic.findInChest(chest, "minecraft:potion", "minecraft:water")
            if wSlot then chest.pushItems(peripheral.getName(stand), wSlot, 1, s) end
        end
        
        -- 2. Add Ingredients (Slot 4)
        for _, step in ipairs(plan) do
            local ing = logic.findInChest(chest, step.name)
            if ing then 
                print(" + Adding " .. step.name)
                chest.pushItems(peripheral.getName(stand), ing, 1, 4)
                os.sleep(22)
            end
        end
        
        -- 3. Clear Stand
        for s = 1, 3 do stand.pushItems(tName, s, 1) end
        
        print("\nBatch Complete. Empty Turtle Slot 1.")
        while turtle.getItemCount() > 0 do os.sleep(1) end
    end
    isBrewing = false
    mainMenu()
end

-----------------------------------------------------------
-- SUB-MENU: Brewing & Quantity
-----------------------------------------------------------
local function brewQuantityMenu(name)
    local max = logic.calculateMaxBrews(name, recipes)
    local items = {
        { text = "START BREW", handler = function()
            term.clear()
            term.setCursorPos(1, 2)
            print("Enter batch quantity (Max " .. max .. "):")
            local qty = tonumber(read())
            if qty and qty > 0 and qty <= max then
                executeBrew(name, qty)
            else
                print("Invalid quantity.")
                os.sleep(1)
                mainMenu()
            end
        end},
        { text = "BACK", handler = mainMenu }
    }
    ui.new(name:upper() .. " (MAX: " .. max .. ")", items):run()
end

local function craftableMenu()
    local items = {}
    -- Sort recipes alphabetically for the menu
    local names = {}
    for n in pairs(recipes) do table.insert(names, n) end
    table.sort(names)

    for _, name in ipairs(names) do
        local m = logic.calculateMaxBrews(name, recipes)
        if m > 0 then
            table.insert(items, { 
                text = name:upper() .. " (" .. m .. ")", 
                handler = function() brewQuantityMenu(name) end 
            })
        end
    end
    
    table.insert(items, { text = "BACK", handler = mainMenu })
    ui.new("CRAFTABLE POTIONS", items):run()
end

-----------------------------------------------------------
-- SUB-MENU: Missing Ingredients
-----------------------------------------------------------
local function showMissingDetails(name)
    term.clear()
    term.setCursorPos(1, 2)
    term.setTextColor(colors.yellow)
    print("RECIPE FOR: " .. name:upper())
    term.setTextColor(colors.white)
    
    local plan = logic.getBrewingPlan(name, recipes)
    for _, step in ipairs(plan) do
        local count = logic.getStock(step.name)
        if count == 0 then
            term.setTextColor(colors.red)
            print(" [X] " .. step.name)
        else
            term.setTextColor(colors.green)
            print(" [OK] " .. step.name .. " (" .. count .. ")")
        end
    end
    
    print("\nPress any key to go back...")
    os.pullEvent("key")
    mainMenu()
end

local function missingMenu()
    local items = {}
    for name, _ in pairs(recipes) do
        if logic.calculateMaxBrews(name, recipes) == 0 then
            table.insert(items, { text = name:upper(), handler = function() showMissingDetails(name) end })
        end
    end
    table.insert(items, { text = "BACK", handler = mainMenu })
    ui.new("UNCRAFTABLE", items):run()
end

-----------------------------------------------------------
-- SUB-MENUS: Status & Admin
-----------------------------------------------------------
local function statusScreen()
    term.clear()
    term.setCursorPos(1, 2)
    term.setTextColor(colors.yellow)
    print("-- SYSTEM STATUS --")
    term.setTextColor(colors.white)
    print("Water:    " .. logic.getStock("_water"))
    print("Awkward:  " .. logic.getStock("_awkward"))
    print("Blaze:    " .. logic.getStock("minecraft:blaze_powder"))
    print("Bottles:  " .. logic.getStock("minecraft:glass_bottle"))
    print("\nPress any key to return...")
    os.pullEvent("key")
    mainMenu()
end

local function adminMenu()
    local items = {
        { text = "GLOBAL EJECT", handler = function() 
            print("Ejecting all inventories...")
            logic.globalEject(chest, stand, tName) 
            os.sleep(1)
            mainMenu()
        end },
        { text = "BACK", handler = mainMenu }
    }
    ui.new("ADMIN TOOLS", items):run()
end

-----------------------------------------------------------
-- MAIN MENU & PARALLEL TASKS
-----------------------------------------------------------
function mainMenu()
    local items = {
        { text = "BREW", handler = craftableMenu },
        { text = "MISSING", handler = missingMenu },
        { text = "STATUS", handler = statusScreen },
        { text = "ADMIN TOOLS", handler = adminMenu }
    }
    ui.new("ALCH-OS v3.5", items):run()
end

local function backgroundWorker()
    while true do
        logic.updateSnapshot(chest)
        if not isBrewing then
            -- Maintenance
            logic.fillWaterBottles(chest, tName)
            logic.manageFuel(chest, stand)
            
            -- Auto-Crafting (Rods & Glass)
            if logic.getStock("minecraft:blaze_powder") < 5 then logic.craftBlazePowder(chest, tName) end
            if logic.getStock("minecraft:glass_bottle") < 6 then logic.craftBottles(chest, tName) end
            
            -- Simple Sorter
            local keepers = {["minecraft:potion"]=true, ["minecraft:glass_bottle"]=true, ["minecraft:blaze_powder"]=true, ["minecraft:nether_wart"]=true, ["minecraft:glass"]=true, ["minecraft:blaze_rod"]=true}
            for _, r in pairs(recipes) do keepers[r.ingredient] = true end
            for i=1, 16 do
                local itm = turtle.getItemDetail(i)
                if itm and not keepers[itm.name] then turtle.select(i) turtle.dropDown() end
            end
        end
        os.sleep(5)
    end
end

-- Launch System
parallel.waitForAny(backgroundWorker, function()
    while true do 
        mainMenu() 
    end
end)
