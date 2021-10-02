---------------------------------------------------------------------------
-- SoarETX F3K score keeper widget                                       --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2021-09-27                                                   --
-- Version: 0.9                                                          --
--                                                                       --
-- Copyright (C) Jesper Frickmann                                        --
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

local name = "SoarF3K"

local options = {
  { "BgColor", COLOR, WHITE },
  { "BgOpacity", VALUE, 8, 0, 15 },
  { "Battery", VALUE, 70, 0, 105 }
}

local function update(widget, options)
  widget.update(options)
end

local function create(zone, options)
  -- Loadable code chunk is called immediately and returns a widget table
  return loadScript("/WIDGETS/" .. name .. "/loadable.lua")(zone, options)
end

local function refresh(widget, event, touchState)
  widget.background()
  widget.gui.run(event, touchState)
end

local function background(widget)
  widget.background()
end

return {
  name = name, 
  create = create, 
  refresh = refresh, 
  options = options, 
  update = update, 
  background = background
}