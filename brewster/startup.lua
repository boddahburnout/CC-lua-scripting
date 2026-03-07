local recipes = require("recipes")
local logic = require("logic")
local ui = require("ui")

if not logic then error("logic.lua missing") end

local chest = peripheral.find("minecraft:chest")
local stand = peripheral.find("minecraft:brewing_stand")
local modem = peripheral.find("modem")
local tName = modem and modem.getNameLocal() or "turtle"
local isBrewing = false

term.clear()
term.setCursorPos(1,1)
print("ALCH-OS: Syncing...")
logic.updateSnapshot(chest)

local mainMenu, craftableMenu, missingMenu, statusScreen, adminMenu

local function executeBrew(name, amt, silent)
    isBrewing = true
    local plan = logic.getBrewingPlan(name, recipes)
    
    for b = 1, amt do
        if not silent then
            term.clear()
            term.setCursorPos(1, 2)
            print("ORDER: " .. name:upper() .. " (" .. b .. "/" .. amt .. ")")
        end

        logic.purgeStand(stand, tName, chest)
        
        local hasAwkward = (logic.getStock("_awkward") >= 3 and name ~= "awkward")
        local startType = hasAwkward and "awkward" or "water"
        
        for s = 1, 3 do 
            local bSlot = logic.findInChest(chest, "minecraft:potion", startType)
            if bSlot then chest.pushItems(peripheral.getName(stand), bSlot, 1, s) end
        end

        for _, step in ipairs(plan) do
            if not (startType == "awkward" and step.name == "minecraft:nether_wart") then
                local ing = logic.findInChest(chest, step.name)
                if ing then 
                    if not silent then print(" + Adding " .. step.name) end
                    chest.pushItems(peripheral.getName(stand), ing, 1, 4)
                    os.sleep(22)
                end
            end
        end
        
        for s = 1, 3 do stand.pushItems(tName, s, 1) end
        
        if name == "awkward" or turtle.getItemCount(16) > 0 then
            for i = 1, 16 do 
                if turtle.getItemCount(i) > 0 then chest.pullItems(tName, i) end 
            end
        else
            if not silent then 
                term.setTextColor(colors.green)
                print("Order Ready!") 
                term.setTextColor(colors.white)
            end
        end
    end
    
    isBrewing = false
    if not silent then mainMenu() end
end

local function brewQuantityMenu(name)
    local max = logic.calculateMaxBrews(name, recipes)
    local items = {
        { text = "START", handler = function()
            term.clear()
            term.setCursorPos(1, 2)
            print("Qty (Max " .. max .. "):")
            local q = tonumber(read())
            if q and q > 0 and q <= max then executeBrew(name, q) else mainMenu() end
        end},
        { text = "BACK", handler = function() craftableMenu() end }
    }
    ui.new(name:upper(), items):run()
end

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

function missingMenu()
    local items = {}
    for n, _ in pairs(recipes) do
        if n ~= "awkward" and logic.calculateMaxBrews(n, recipes) == 0 then
            table.insert(items, { text = n:upper(), handler = function() 
                term.clear()
                print("RECIPE: " .. n:upper())
                local p = logic.getBrewingPlan(n, recipes)
                for _, s in ipairs(p) do
                    local c = logic.getStock(s.name)
                    term.setTextColor(c == 0 and colors.red or colors.green)
                    print(" [" .. (c == 0 and "X" or "OK") .. "] " .. s.name)
                end
                term.setTextColor(colors.white)
                print("\nPress any key...")
                os.pullEvent("key")
                missingMenu()
            end })
        end
    end
    table.insert(items, { text = "BACK", handler = function() mainMenu() end })
    ui.new("UNCRAFTABLE", items):run()
end

function statusScreen()
    term.clear()
    term.setCursorPos(1, 2)
    print("STATUS:")
    print("Water:   " .. logic.getStock("_water"))
    print("Awkward: " .. logic.getStock("_awkward"))
    print("Fuel:    " .. logic.getStock("minecraft:blaze_powder"))
    print("\nAny key...")
    os.pullEvent("key")
    mainMenu()
end

function adminMenu()
    local items = {
        { text = "EJECT ALL", handler = function() logic.globalEject(chest, stand, tName) mainMenu() end },
        { text = "BACK", handler = function() mainMenu() end }
    }
    ui.new("ADMIN", items):run()
end

function mainMenu()
    local items = {
        { text = "BREW", handler = function() craftableMenu() end },
        { text = "MISSING", handler = function() missingMenu() end },
        { text = "STATUS", handler = function() statusScreen() end },
        { text = "ADMIN", handler = function() adminMenu() end }
    }
    ui.new("ALCH-OS v3.8", items):run()
end

local function backgroundWorker()
    while true do
        logic.updateSnapshot(chest)
        if not isBrewing then
            if logic.getStock("_awkward") < 15 then
                local can = logic.getStock("minecraft:nether_wart") > 0 and 
                            (logic.getStock("_water") + logic.getStock("minecraft:glass_bottle")) >= 3
                if can then executeBrew("awkward", 1, true) end
            end
            logic.fillWaterBottles(chest, tName)
            logic.manageFuel(chest, stand)
            if logic.getStock("minecraft:blaze_powder") < 5 then logic.craftBlazePowder(chest, tName) end
            if logic.getStock("minecraft:glass_bottle") < 6 then logic.craftBottles(chest, tName) end
            
            local k = {["minecraft:glass_bottle"]=true, ["minecraft:blaze_powder"]=true, ["minecraft:nether_wart"]=true, ["minecraft:glass"]=true, ["minecraft:blaze_rod"]=true}
            for _, r in pairs(recipes) do k[r.ingredient] = true end
            
            for i = 1, 16 do
                local itm = turtle.getItemDetail(i)
                if itm then
                    local pType = logic.getPotionType(itm)
                    -- MOVE TO CHEST IF: It's an ingredient OR it's specifically an Awkward Potion
                    if k[itm.name] or pType == "awkward" then
                        turtle.select(i)
                        chest.pullItems(tName, i) 
                    -- REJECT IF: It's not a potion at all (Junk)
                    elseif pType == "not_a_potion" then
                        turtle.select(i)
                        turtle.dropDown()
                    -- LEAVE ALONE IF: It's a "final_potion" (Strength, Invis, etc.)
                    end
                end
            end
        end
        os.sleep(5)
    end
end

parallel.waitForAny(backgroundWorker, function()
    while true do mainMenu() end
end)
