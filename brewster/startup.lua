local recipes = require("recipes")
local logic = require("logic")
local ui = require("ui")

local chest = peripheral.find("minecraft:chest")
local stand = peripheral.find("minecraft:brewing_stand")
local modem = peripheral.find("modem")
local tName = modem and modem.getNameLocal() or "turtle"
local isBrewing = false

local mainMenu

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
        for s = 1, 3 do 
            local wSlot = logic.findInChest(chest, "minecraft:potion", "minecraft:water")
            if wSlot then chest.pushItems(peripheral.getName(stand), wSlot, 1, s) end
        end
        for _, step in ipairs(plan) do
            local ing = logic.findInChest(chest, step.name)
            if ing then 
                print(" + Adding " .. step.name)
                chest.pushItems(peripheral.getName(stand), ing, 1, 4)
                os.sleep(22)
            end
        end
        for s = 1, 3 do stand.pushItems(tName, s, 1) end
        print("\nBatch Complete. Empty Turtle Slot 1.")
        while turtle.getItemCount() > 0 do os.sleep(1) end
    end
    isBrewing = false
    mainMenu()
end

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

local function craftableMenu()
    local items = {}
    local names = {}
    for n in pairs(recipes) do table.insert(names, n) end
    table.sort(names)
    for _, n in ipairs(names) do
        local m = logic.calculateMaxBrews(n, recipes)
        if m > 0 then table.insert(items, { text = n:upper() .. " ("..m..")", handler = function() brewQuantityMenu(n) end }) end
    end
    table.insert(items, { text = "BACK", handler = mainMenu })
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
    mainMenu()
end

local function missingMenu()
    local items = {}
    for n, _ in pairs(recipes) do
        if logic.calculateMaxBrews(n, recipes) == 0 then
            table.insert(items, { text = n:upper(), handler = function() showMissingDetails(n) end })
        end
    end
    table.insert(items, { text = "BACK", handler = mainMenu })
    ui.new("UNCRAFTABLE", items):run()
end

local function statusScreen()
    term.clear()
    term.setCursorPos(1, 2)
    print("STATUS:")
    print("Water:    " .. logic.getStock("_water"))
    print("Awkward:  " .. logic.getStock("_awkward"))
    print("Fuel:     " .. logic.getStock("minecraft:blaze_powder"))
    print("\nPress any key...")
    os.pullEvent("key")
    mainMenu()
end

local function adminMenu()
    local items = {
        { text = "GLOBAL EJECT", handler = function() logic.globalEject(chest, stand, tName) mainMenu() end },
        { text = "BACK", handler = mainMenu }
    }
    ui.new("ADMIN", items):run()
end

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
            logic.fillWaterBottles(chest, tName)
            logic.manageFuel(chest, stand)
            if logic.getStock("minecraft:blaze_powder") < 5 then logic.craftBlazePowder(chest, tName) end
            if logic.getStock("minecraft:glass_bottle") < 6 then logic.craftBottles(chest, tName) end
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

parallel.waitForAny(backgroundWorker, function()
    while true do mainMenu() end
end)
