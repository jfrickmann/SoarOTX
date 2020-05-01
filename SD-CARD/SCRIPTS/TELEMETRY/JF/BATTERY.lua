-- JF/BATTERY.lua
-- Timestamp: 2020-05-01
-- Created by Jesper Frickmann

local ui = {} -- List of shared variables
ui.bat10 = model.getGlobalVariable(soarUtil.GV_BAT, soarUtil.FM_ADJUST)

local Draw = soarUtil.LoadWxH("JF/BATTERY.lua", ui) -- Screen size specific function

local function run(event)
	-- Press EXIT to quit
	if soarUtil.EvtExit(event) then
		return true
	end

	-- Adjust battery warning threshold
	if soarUtil.EvtInc(event) then
		ui.bat10 = math.min(100, ui.bat10 + 1)
		model.setGlobalVariable(soarUtil.GV_BAT, soarUtil.FM_ADJUST, ui.bat10)
	end
	
	if soarUtil.EvtDec(event) then
		ui.bat10 = math.max(10, ui.bat10 - 1)
		model.setGlobalVariable(soarUtil.GV_BAT, soarUtil.FM_ADJUST, ui.bat10)
	end
	
	Draw()
end -- run()

return{run = run}