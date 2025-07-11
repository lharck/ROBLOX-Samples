--[[
 Initalizes classes for all exercise machines in the workspace.
]]
 
local CollectionService = game:GetService("CollectionService")
local ExerciseController = require(game.ServerScriptService.ServerModules.Training.ExerciseController)

for _, machineModel in pairs(CollectionService:GetTagged("ExerciseMachine")) do
	if not machineModel:IsDescendantOf(workspace) then continue end

    -- creates new exercise controller, run in pcall incase error
	local success, error_message = pcall(function() ExerciseController.new(machineModel) end)

	if not success then
		local stackTrace = debug.traceback(error_message, 2)
		warn(machineModel.Name .. " has errored in creation, with error: " .. error_message .. "\nStack Trace:\n" .. stackTrace)
	end
end

