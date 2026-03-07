local recipes = require("recipes")
local logic = require("logic")
local ui = require("ui")

local chest = peripheral.find("minecraft:chest")
local stand = peripheral.find("minecraft:brewing_stand")
local modem = peripheral.find("modem")
local tName = modem and modem.getNameLocal() or "turtle"
local isBrewing = false

-- FORWARD DECLARATIONS (Prevents the nil handler error)
local mainMenu, craftableMenu, missingMenu, statusScreen, adminMenu

-----------------------------------------------------------
-- 1. CORE ENGINE: Purge-Ready Brewing
-----------------------------------------------------------
local function executeBrew(name, amt, silent)
    isBrewing = true
    local plan = logic.getBrewingPlan(name, recipes)
    
    for b = 1, amt do
        if not silent then
            term.clear()
            term.setCursorPos(1, 2)
            print("ORDER: " .. name:upper() .. " (" .. b .. "/" .. amt .. ")")
        end

        -- HARD RESET: Purge stand and turtle into chest
        if not silent then print("Purging hardware...") end
        logic.purgeStand(stand, tName, chest)
        
        -- Identify Base (Strict NBT Check)
        local hasAwkward = logic.getStock("_awkward") >= 3
        local startType = (hasAwkward and name ~= "awkward") and "minecraft:awkward" or "minecraft:water"
        
        -- Load Bottles
        for s = 1, 3 do 
            local bSlot = logic.findInChest(chest, "minecraft:potion", startType)
            if bSlot then chest.pushItems(peripheral.getName(stand), bSlot, 1, s) end
        end

        -- Follow Recipe Plan
        for _, step in ipairs(plan) do
            if not (startType == "minecraft:awkward" and step.name == "minecraft:nether_wart") then
                local ing = logic.findInChest(chest, step.name)
                if ing then 
                    if not silent then print(" + Adding " .. step.name) end
                    chest.pushItems(peripheral.getName(stand), ing, 1, 4)
                    os.sleep(22)
                end
            end
        end
        
        -- AUTO-STORAGE: Move results directly to chest
        for s = 1, 3 do stand.pushItems(tName, s, 1) end
        for i = 1, 16 do if turtle.getItemCount(i) > 0 then chest.pullItems(tName, i) end end
    end
    
    isBrewing = false
    if not silent then mainMenu() end
end

-----------------------------------------------------------
-- 2. MENU DEFINITIONS
-----------------------------------------------------------

-- Quantity Sub-Menu
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

-- Craftable Selection
function craftableMenu()
    local items = {}
    local names = {}
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

-- Missing Ingredient Logic
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
-- 3. BACKGROUND MAINTENANCE
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

            -- 2. Physical Maintenance
            logic.fillWaterBottles(chest, tName)
            logic.manageFuel(chest, stand)
            if logic.getStock("minecraft:blaze_powder") < 5 then logic.craftBlazePowder(chest, tName) end
            if logic.getStock("minecraft:glass_bottle") < 6 then logic.craftBottles(chest, tName) end
            
            -- 3. Inventory Cleanup
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
-- 4. BOOT
-----------------------------------------------------------
parallel.waitForAny(backgroundWorker, function()
    while true do mainMenu() end
end)
