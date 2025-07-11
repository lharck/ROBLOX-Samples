--[[
 Any user who gets in the way of the person using the machine
 will be moved out of the way 
]]
 
BootNonUsers = {}
BootNonUsers.__index = BootNonUsers

local IdGenerator = require(game.ReplicatedStorage:WaitForChild("SharedUtilities"):WaitForChild("IdGenerator"))
local POSITIONS = game.Workspace.DummyTeleportPositions:GetChildren()

-- constructor for BootNonUsers
function BootNonUsers.new(exerciseController)
	local self = {}
	setmetatable(self, BootNonUsers)
	
	self.ExerciseController = exerciseController	
	
	self:initEvents()
	
	return self
end

-- method called when a non machine user enters the blocked area
function BootNonUsers:OnAreaEntered(objectTouching)
	local playerWhoTriggeredTouch = game.Players:GetPlayerFromCharacter(objectTouching.Parent)
	local personIsBlocking = self.ExerciseController.PlayerUsingMachine ~= playerWhoTriggeredTouch

	if not self.ExerciseController.PlayerUsingMachine or not playerWhoTriggeredTouch then return end 

	if personIsBlocking then 
		local randomPosition = POSITIONS[math.random(1,#POSITIONS)]
		playerWhoTriggeredTouch.Character.Torso.CFrame = randomPosition.CFrame 
	end
end

-- initalize events for the BootNonUsers class
function BootNonUsers:initEvents()
	local machine = self.ExerciseController.Model
	
	machine.BlockedArea1.Transparency = 1
	machine.BlockedArea2.Transparency = 1
	
	machine.BlockedArea1.Touched:Connect(function(objectTouching)
		self:OnAreaEntered(objectTouching)
	end)

	machine.BlockedArea2.Touched:Connect(function(objectTouching)
		self:OnAreaEntered(objectTouching)
	end)
end

return BootNonUsers