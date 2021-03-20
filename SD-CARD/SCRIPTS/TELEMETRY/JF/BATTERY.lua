-- JF/BATTERY.lua
-- Timestamp: 2021-03-20
-- Created by Jesper Frickmann

local ui = {} -- List of shared variables
ui.bat10 = model.getGlobalVariable(soarUtil.GV_BAT, soarUtil.FM_ADJUST)

local Draw = soarUtil.LoadWxH("JF/BATTERY.lua", ui) -- Screen size specific function

local function run(event)
	-- Press ENTER OR EXIT to quit
	if event == EVT_VIRTUAL_ENTER or event == EVT_VIRTUAL_EXIT then
		return true
	end

	-- Adjust battery warning threshold
	if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
		ui.bat10 = math.min(400, ui.bat10 + 1)
		model.setGlobalVariable(soarUtil.GV_BAT, soarUtil.FM_ADJUST, ui.bat10)
	end
	
	if event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
		ui.bat10 = math.max(10, ui.bat10 - 1)
		model.setGlobalVariable(soarUtil.GV_BAT, soarUtil.FM_ADJUST, ui.bat10)
	end
	
	Draw()
end -- run()

return{run = run}