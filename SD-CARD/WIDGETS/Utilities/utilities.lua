---------------------------------------------------------------------------
-- The dynamically loadable part of the shared Lua utilities library.    --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2021-XX-XX                                                   --
-- Version: 0.9                                                          --
--                                                                       --
-- Copyright (C) EdgeTX                                                  --
--                                                                       --
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               --
--                                                                       --
-- This program is free software; you can redistribute it and/or modify  --
-- it under the terms of the GNU General Public License version 2 as     --
-- published by the Free Software Foundation.                            --
--                                                                       --
-- This program is distributed in the hope that it will be useful        --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of        --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         --
-- GNU General Public License for more details.                          --
---------------------------------------------------------------------------
local widgetSizes = {
  {392, 170},
  {196, 170},
  {196, 85},
  {196, 42},
  {70, 39}
}

local function utilities(dir)
  local function load4screen(file, ...)
    local filename = dir .. file .. "_" .. LCD_W .. "x" .. LCD_H .. ".lua"
    local chunk = loadScript(filename)
    return chunk(...)
  end -- load4screen(...)
  
  local function load4zone(file, zone, ...)
    local w, h = zone.w, zone.h
    
    for i, wh in ipairs(widgetSizes) do
      if wh[1] <= w and wh[2] <= h then
        local filename = dir .. file .. "_" .. wh[1] .. "x" .. wh[2] .. ".lua"
        local chunk = loadScript(filename)
        if chunk then
          return chunk(...)
        end
      end
    end
    
    print("----> load4zone could not find a script for: " .. dir .. file)
  end -- load4zone(...)

  -- Set a widget refresh function for non-fullscreen mode for GUI to call
  local function setWidgetRefresh(f)
    widgetRefresh = f
  end -- setWidgetRefresh
    
  -- Create a new GUI object with interactive screen elements
  local function GUI()
    local handlers = { }
    local elements = { }
    local focus = 1
    local edit = false

    -- Set a refresh function for fullscreen mode
    local function setFullScreenRefresh(f)
      fullScreenRefresh = f
    end -- setWidgetRefresh
    
    -- Set a handler for event (if no element is being edited)
    local function setHandler(event, f)
      table.insert(handlers, {event, f} )
    end -- setHandler
    
    -- Move focus to another element
    local function moveFocus(delta)
      repeat
        focus = focus + delta
        if focus > #elements then
          focus = 1
        elseif focus < 1 then
          focus = #elements
        end
      until not elements[focus].noFocus
    end -- moveFocus(...)
    
    -- Add an element and return it to the client
    local function addElement(element)
      local idx = #elements + 1
      elements[idx] = element
      return element
    end -- addElement(...)
    
    -- Run an event cycle
    local function run(event, touchState)
      if not event then -- widget mode; event == nil
        if widgetRefresh then
          widgetRefresh()
        else
          lcd.drawText(1, 1, "No widget refresh function was loaded.")
        end
      else -- full screen mode; event is a value
        fullScreenRefresh(event, touchState)
        for idx, element in ipairs(elements) do
          element.draw(idx)
        end
        -- Process event if non-zero
        if event ~= 0 then
          if edit then -- Send the event to the element being edited
            elements[focus].run(focus, event, touchState)
          else
            -- Is the event being "handled"?
            for idx, h in ipairs(handlers) do
              local evt, f = h[1], h[2]
              if event == evt then
                return f()
              end
            end
            -- Move focus or send event to the focused element
            if event == EVT_TOUCH_FIRST then
              for idx, element in ipairs(elements) do
                if element.covers(touchState.x, touchState.y) then
                  if not element.noFocus then
                    focus = idx
                  end
                  break
                end
              end
            elseif event == EVT_VIRTUAL_NEXT then
              moveFocus(1)
            elseif event == EVT_VIRTUAL_PREV then
              moveFocus(-1)
            else
              elements[focus].run(focus, event, touchState)
            end
          end
        end
      end
    end -- run(...)

    -- Create a button to trigger a function
    local function button(x, y, w, h, txt, callBack)
      local function draw(idx)
        local att = 0
        
        lcd.drawFilledRectangle(x, y, w, h, FOCUS_BGCOLOR)
        if focus == idx then
          att = BOLD
          lcd.drawRectangle(x, y, w, h, HIGHLIGHT_COLOR)
        end
        lcd.drawText(x + w / 2, y + 2, txt, CENTER + FOCUS_COLOR + att)
      end
      
      local function run(idx, event, touchState)
        if event == EVT_VIRTUAL_ENTER or event == EVT_TOUCH_TAP or event == EVT_TOUCH_BREAK then
          callBack()
        end
      end
      
      local function title(t)
        txt = t
      end
      
      local function covers(p, q)
        return (x <= p and p <= x + w and y <= q and q <= y + h)
      end
      
      return addElement( {draw = draw, run = run, title = title, covers = covers} )
    end -- button(...)
    
    -- Create a toggle button that turns on/off. callBack gets true/false
    local function toggleButton(x, y, w, h, txt, value, callBack)
      local function draw(idx)
        local bg = FOCUS_BGCOLOR
        local att = 0
        local border

        if value then bg = HIGHLIGHT_COLOR end
        
        if focus == idx then 
          att = BOLD 
          if value then
            border = FOCUS_BGCOLOR
          else
            border = HIGHLIGHT_COLOR 
          end
        end
        
        lcd.drawFilledRectangle(x, y, w, h, bg)
        lcd.drawText(x + w / 2, y + 2, txt, CENTER + FOCUS_COLOR + att)
        if border then
          lcd.drawRectangle(x, y, w, h, border)
        end
      end
      
      local function run(idx, event, touchState)
        if event == EVT_VIRTUAL_ENTER or event == EVT_TOUCH_TAP or event == EVT_TOUCH_BREAK then
          value = not value
          callBack(value)
        end
      end
      
      local function title(t)
        txt = t
      end
      
      local function set(v)
        value = v
      end
      
      local function covers(p, q)
        return (x <= p and p <= x + w and y <= q and q <= y + h)
      end
      
      return addElement( {draw = draw, run = run, title = title, covers = covers, set = set} )
    end -- toggleButton(...)
    
    -- Create a menu of choices. callBack gets choice #
    local function menu(items, callBack)
      local function draw(idx)
      end
      
      local function run(idx, event, touchState)
      end
      
      local function covers(p, q)
        return (x <= p and p <= x + w and y <= q and q <= y + h)
      end
      
      return addElement( {draw = draw, run = run, covers = covers} )
    end -- menu(...)
    
    -- Create a display of current time on timer[tmr]
    local function timer(x, y, w, h, tmr, callBack)
      local function draw(idx)
      end
      
      local function run(idx, event, touchState)
      end
      
      local function covers(p, q)
        return (x <= p and p <= x + w and y <= q and q <= y + h)
      end
      
      return addElement( {draw = draw, run = run, covers = covers, noFocus = true} )
    end -- timer(...)
    
    -- Create a number that can be edited
    local function number(x, y, value, callBack)
      local function draw(idx)
      end
      
      local function run(idx, event, touchState)
      end
      
      local function covers(p, q)
        return (x <= p and p <= x + w and y <= q and q <= y + h)
      end
      
      return addElement( {draw = draw, run = run, covers = covers} )
    end -- number(...)
    
    return {
      setFullScreenRefresh = setFullScreenRefresh,
      setHandler = setHandler,
      run = run,
      button = button,
      toggleButton = toggleButton,
      menu = menu,
      timer = timer,
      number, number
    }
  end -- gui(...)
  
  return {
    load4screen = load4screen,
    load4zone = load4zone,
    setWidgetRefresh = setWidgetRefresh,
    GUI = GUI
  }
end

return utilities