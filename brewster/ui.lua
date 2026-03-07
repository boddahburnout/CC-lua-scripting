local ui = {}

function ui.new(title, items)
    local menu = {
        title = title or "Menu",
        items = items,
        selected = 1,
        offset = 0, -- Track scrolling
        running = true
    }

    local w, h = term.getSize()
    local maxDisplay = h - 6 -- Reserve space for Title and Header

    function menu:draw()
        term.clear()
        
        -- Draw Title
        term.setTextColor(colors.yellow)
        local titleDisplay = "-- " .. self.title .. " --"
        term.setCursorPos(math.floor((w - #titleDisplay) / 2) + 1, 2)
        term.write(titleDisplay)
        
        -- Calculate Scroll Offset
        -- If selection moves past the bottom of the window, scroll down
        if self.selected > self.offset + maxDisplay then
            self.offset = self.selected - maxDisplay
        -- If selection moves above the top of the window, scroll up
        elseif self.selected <= self.offset then
            self.offset = self.selected - 1
        end

        -- Draw Items within the window
        for i = 1, maxDisplay do
            local itemIdx = i + self.offset
            local item = self.items[itemIdx]
            
            if item then
                local y = 4 + i
                local isSelected = (itemIdx == self.selected)
                
                local display = isSelected and "[  " .. item.text .. "  ]" or item.text
                local x = math.floor((w - #display) / 2) + 1
                
                term.setCursorPos(x, y)
                term.setTextColor(isSelected and colors.white or colors.gray)
                term.write(display)
            end
        end
        
        -- Draw Scroll Indicators if needed
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
            if item and type(item.handler) == "function" then
                term.clear()
                term.setCursorPos(1, 1)
                item.handler() -- This is the call that was failing
                self.running = false
            else
                -- Optional: Sound a beep or print a warning if handler is missing
                os.queueEvent("fake_event") -- Just to keep the loop alive
            end
            elseif key == keys.q then -- Added a 'quit' shortcut
                self.running = false
            end
        end
    end

    return menu
end

return ui
