local ui = {}

function ui.new(title, items)
    local menu = {
        title = title or "Menu",
        items = items or {},
        selected = 1,
        offset = 0,
        running = true
    }

    local w, h = term.getSize()
    local maxDisplay = h - 6 

    function menu:draw()
        term.clear()
        
        -- Draw Title
        term.setTextColor(colors.yellow)
        local titleDisplay = "-- " .. self.title .. " --"
        term.setCursorPos(math.floor((w - #titleDisplay) / 2) + 1, 2)
        term.write(titleDisplay)
        
        -- SCROLLING LOGIC FIX:
        -- 1. Handle looping back to top
        if self.selected == 1 then
            self.offset = 0
        -- 2. Handle looping back to bottom
        elseif self.selected == #self.items and #self.items > maxDisplay then
            self.offset = #self.items - maxDisplay
        -- 3. Standard scroll down
        elseif self.selected > self.offset + maxDisplay then
            self.offset = self.selected - maxDisplay
        -- 4. Standard scroll up
        elseif self.selected <= self.offset then
            self.offset = self.selected - 1
        end

        -- Draw Items
        for i = 1, maxDisplay do
            local itemIdx = i + self.offset
            local item = self.items[itemIdx]
            
            if item then
                local y = 4 + i
                local isSelected = (itemIdx == self.selected)
                
                -- Note: Ensure the spaces in "[  ]" match your preference
                local display = isSelected and "[  " .. item.text .. "  ]" or item.text
                local x = math.floor((w - #display) / 2) + 1
                
                term.setCursorPos(x, y)
                term.setTextColor(isSelected and colors.white or colors.gray)
                term.write(display)
            end
        end
        
        -- Indicators
        term.setTextColor(colors.orange)
        if self.offset > 0 then
            term.setCursorPos(w, 5)
            term.write("^")
        end
        if self.offset + maxDisplay < #self.items then
            term.setCursorPos(w, 4 + maxDisplay)
            term.write("v")
        end
    end

    function menu:run()
        while self.running do
            self:draw()
            local _, key = os.pullEvent("key")
            
            if key == keys.up then
                self.selected = self.selected > 1 and self.selected - 1 or #self.items
            elseif key == keys.down then
                self.selected = self.selected < #self.items and self.selected + 1 or 1
            elseif key == keys.enter then
                local item = self.items[self.selected]
                -- SAFETY CHECK: Ensure item and handler exist
                if item and type(item.handler) == "function" then
                    term.clear()
                    term.setCursorPos(1, 1)
                    item.handler()
                    self.running = false
                else
                    -- If no handler, just exit the menu or ignore
                    self.running = false
                end
            elseif key == keys.q then
                self.running = false
            end
        end
    end

    return menu
end

return ui
