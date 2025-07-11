--[[
 Class for managing an Exercise 
 Keeps track of who's using the machine
 Resets the machine when player stops exercise abruptly, or when the exercise is done
]]
Controller = {}

local IdGenerator = require(game.ReplicatedStorage:WaitForChild("SharedUtilities"):WaitForChild("IdGenerator"))
local Remotes = game.ReplicatedStorage:WaitForChild("Remotes")
local Data = require(game.ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("PlayerDataModule"))

-- Creates new controller that handles when a player starts and stops doing an exercise
function Controller.new(exerciseModel)
	local self = {}
	setmetatable(self, {__index = Controller})
	
	self.Id = IdGenerator.getUniqueId()
	self.ExerciseInstance = self:_CreateSpecificExercise(exerciseModel) -- the exercise to be controlled
	self.IsInUse = false
	self.OriginalCharCFrame = nil
	
	self:_Clean() -- clean controller to default state
	self:_InitEvents() -- initalize associated ROBLOX events

	return self
end

-- create new instance of exercise type
function Controller:_CreateSpecificExercise(exerciseModel)
	local exerciseType = exerciseModel.Properties.ExerciseType.Value
	local SpecificExerciseModule = require(game.ServerScriptService.ServerModules.Training[exerciseType])
	
	return SpecificExerciseModule.new(exerciseModel)
end

-- Events that gets initialized when this module is created
function Controller:_InitEvents()
	local promptPart = self.ExerciseInstance.Model.PromptPart

	-- prompts the user to start the exercise when the player is in range of the machine
	promptPart.Touched:Connect(function(hitPart)
		self:_OnMachineTouched(hitPart)
	end)

	-- tells the exercise to start when the player clicks the start exercise button
	Remotes.Exercises.ExerciseStart.OnServerEvent:Connect(function(player, machineId)
		local matchingExercise = tonumber(machineId) == self.Id

		if not self:_PlayerCanUseMachine(player) then return end
		
		-- If the id requested and machine id don't match then must be a different machine
		if not matchingExercise or not player then return end 

		self:_StartExercise(player, machineId)
	end)
end

function Controller:_StartExercise(player, machineId)
	local character = player.Character
	self.OriginalCharCFrame = character.Torso.CFrame
	if not character and not character:FindFirstChild("Humanoid") then return end

	-- start the exercise
	-- the exercise is put inside a thread so that we can stop the exercise at any time
	self.CurrentExerciseThread = task.spawn(function()
		local function _endExercise(isAbruptCancel)
			self:_ToggleMachineInUse(player, false)
			self:_Clean(isAbruptCancel)			
		end
		-- when the player leaves the game, reset the exercise back to defaults
		self.PlayerLeftEvent = player.CharacterRemoving:Connect(function()
			_endExercise(true)
		end)
	
		self:_ToggleMachineInUse(player, true)
		self.ExerciseInstance:Start(player)
		
		_endExercise()
	end)
end

-- when a player touches the machine, prompt the user to start the exercise
function Controller:_OnMachineTouched(hitPart)
	local player = game.Players:GetPlayerFromCharacter(hitPart.Parent)
	if not player then return end

	if self:_PlayerCanUseMachine(player) then		
		Remotes.Exercises.ShowTrainingGui:FireClient(player, 
			string.format(self.ExerciseInstance.Prompt, self.ExerciseInstance.NumReps),
			self.Id, 
			self.ExerciseInstance.Model.PromptPart
		)
	end
end

-- Variables that gets reset when this module is created 
function Controller:_Clean(isAbruptCancel)	
	if isAbruptCancel then
		-- If exercise abruptly cancelled, then we need to cancel the thread
		task.cancel(self.CurrentExerciseThread)
	end
	
	self.CurrentExerciseThread = nil

	if self.PlayerLeftEvent then self.PlayerLeftEvent:Disconnect() end 
	self.PlayerLeftEvent = nil

	self.ExerciseInstance:Clean() -- clean the instance itself
end

function Controller:_ToggleMachineInUse(player, newUseState)
	self.IsInUse = newUseState

	self.ExerciseInstance.Player = self.IsInUse and player or nil
	Data.temp[player].PlayerState = self.IsInUse == false and "Idle" or self.ExerciseInstance.Model:GetAttribute("ExerciseType")
	
	local characterCF = self.IsInUse 
		and self.ExerciseInstance.Model.Torso_Position.CFrame 
		or self.OriginalCharCFrame
	
	player.Character.HumanoidRootPart.Anchored = newUseState
	player.Character.HumanoidRootPart.CFrame = characterCF
	
	self:_SetJumpAndWalkspeed(player.Character, self.IsInUse and 0 or 50, self.IsInUse and 0 or 16)
	player.Character.Humanoid.AutoRotate = not self.IsInUse
end

function Controller:_PlayerCanUseMachine(player)
	local PromptPart = self.ExerciseInstance.Model.PromptPart
	local playerIsCloseToMachine = (player.Character.Torso.Position - PromptPart.Position).Magnitude < PromptPart.Size.X
	local machineIsFree = self.IsInUse == false 
	local playerIsFree = Data.temp[player].PlayerState == "Idle"

	return machineIsFree and playerIsFree and playerIsCloseToMachine
end

function Controller:_SetJumpAndWalkspeed(character, jump, walkspeed)
	character.Humanoid.WalkSpeed = walkspeed
	character.Humanoid.JumpPower = jump	
end

return Controller