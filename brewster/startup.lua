local function executeBrew(name, amt, silent)
    isBrewing = true
    local plan = logic.getBrewingPlan(name, recipes)
    
    for b = 1, amt do
        if not silent then
            term.clear()
            term.setCursorPos(1, 2)
            print("ORDER: " .. name:upper() .. " (" .. b .. "/" .. amt .. ")")
        end

        -- 1. HARD RESET: Scan and Clear Stand and Turtle
        if not silent then print("Purging Stand/Turtle...") end
        logic.purgeStand(stand, tName, chest)

        -- 2. Identify Base (Strict NBT Check)
        -- We EXPLICITLY check if we are making awkward. If so, startType MUST be water.
        local startType = "minecraft:water"
        if name ~= "awkward" and logic.getStock("_awkward") >= 3 then
            startType = "minecraft:awkward"
        end
        
        -- 3. Load Bottles (Strict Search)
        for s = 1, 3 do 
            -- findInChest now does a DEEP scan of every bottle before picking it up
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
        for s = 1, 3 do stand.pushItems(tName, s, 1) end
        for i = 1, 16 do if turtle.getItemCount(i) > 0 then chest.pullItems(tName, i) end end
    end
    
    isBrewing = false
    if not silent then mainMenu() end
end
