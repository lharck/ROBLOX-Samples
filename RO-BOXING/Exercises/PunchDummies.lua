--[[
 PunchDummies exercise class
]]
PunchDummy = {}
PunchDummy.__index = PunchDummy

local sharedModules = game.ReplicatedStorage:WaitForChild("SharedModules")
local serverUtils = game.ServerScriptService:WaitForChild("ServerUtilities")

local glove_module = require(sharedModules:WaitForChild("Add_Rem_Gloves"))
local Data = require(sharedModules:WaitForChild("PlayerDataModule"))
local xpModule = require(serverUtils:WaitForChild("awardXP"))
local animatorRemote = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AnimatorRemote")
local DIRECTIONS = {"Top", "Left", "Right", "Bottom"}

-- constructor for PunchDummy
function PunchDummy.new(model)
	local self = {}
	setmetatable(self, PunchDummy)

	self.Model = model
	self.Player = nil
	self.CharactersOriginalPosition = nil
	self.Clicked = false

	self:initEvents()

	return self
end

-- toggle one of the buttons on the punch dummy to be green
function PunchDummy:MakeButtonGreen(button)
	local player = self.Player	
	local character = player.Character

	local initialMaterial = button.Material
	local speed_level = Data.getValue(player, "SpeedLevel")	
	local speed_amount = 1 + (speed_level/70)

	button.BrickColor = BrickColor.new("Lime green")

	game.ReplicatedStorage.Remotes.xboxButton:FireClient(player, "ShowButton", button)

	local timeStart = tick()
	repeat task.wait() until tick() - timeStart > 5 or self.Clicked or not self.Player

	if self.Clicked then
		xpModule.awardXP(player, "Accuracy", 2)
		_playPunch(character, button.Name.."_Hit", speed_amount, button, self.Model)	
	end

	button.BrickColor = BrickColor.new("Bright red")	
	button.Material = initialMaterial

	game.ReplicatedStorage.Remotes.xboxButton:FireClient(player, "HideButton")

	self.Clicked = false
end

-- XBOX controls for the exercise
function PunchDummy:onXboxButtonPressed(player, command, ...)
	local buttonNames = {
		[Enum.KeyCode.ButtonA] = "Bottom";
		[Enum.KeyCode.ButtonB] = "Right";
		[Enum.KeyCode.ButtonY] = "Top";
		[Enum.KeyCode.ButtonX] = "Left";
	}

	if command == "PressedButton" then
		local keyCode = ...
		local whichButtonPressed = buttonNames[keyCode]
		local buttonPart = self.Model.Buttons [whichButtonPressed]

		local isGreen = buttonPart.BrickColor == BrickColor.new("Lime green")
		local userClicked = player == self.Player
		if not isGreen or not userClicked then return end 

		self.Clicked = true
	end
end


-- Prep the machine to be used
function PunchDummy:PrepareForStart()
	local player = self.Player	
	local character = player.Character

	self.CharactersOriginalPosition = character.HumanoidRootPart.Position
	glove_module.WearGloves(player.Character)
	character:FindFirstChild("HumanoidRootPart").CFrame = CFrame.new(self.Model.Torso_Position.Position)

	animatorRemote:FireClient(player, "Play", "Idle", {Priority = 2, Looped = true}) 
end

-- reset character to original state pre exercise
function PunchDummy:CleanCharacter()
	local player = self.Player
	local character = player.Character 
	local humanoid = character:FindFirstChild("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")

	glove_module.RemoveGloves(character)

	if self.CharactersOriginalPosition then 
		hrp.CFrame = CFrame.new(self.CharactersOriginalPosition)*CFrame.new(0, 2, 0)
	end

	humanoid.Jump = true
	humanoid.WalkSpeed = 16
	humanoid.JumpPower = 50

	-- Stops all player's custom animations
	animatorRemote:FireClient(player, "StopAllAnimations") 
end

-- clean punch dummy class for reuse
function PunchDummy:CleanUp()
	self:CleanCharacter()
	task.wait(.5)

	-- if the player is still in game when we're cleaning up the exercise, reset their state
	if self.Player then
		Data.temp[self.Player].PlayerState = "Idle"
	end

	self.Player = nil
	self.animations = {}
	self.CharactersOriginalPosition = nil
	self.Clicked = false

	for _, button in pairs(self.Model.Buttons:GetChildren()) do
		button.BrickColor = BrickColor.new("Bright red")
	end
end

-- perform a number of reps for the exercise
function PunchDummy:DoReps(NUM_REPS)
	for i = 1, NUM_REPS do
		local chosenDirection = DIRECTIONS[math.random(1, 4)]
		local buttonToClick = self.Model.Buttons[chosenDirection]

		self:MakeButtonGreen(buttonToClick)
		task.wait(.5)
	end
end

-- start the exercise
function PunchDummy:Start(endExercise)
	self:PrepareForStart()		
	self:DoReps(15)
	self:CleanUp()

	endExercise()
end

-- create ROBLOX events associated with the PunchDummy class
function PunchDummy:initEvents()
	-- create click events for buttons
	for _, buttonPart in pairs(self.Model.Buttons:GetChildren())do
		buttonPart.Material = Enum.Material.SmoothPlastic

		buttonPart.ClickDetector.MouseClick:Connect(function(playerWhoClicked)
			local isGreen = buttonPart.BrickColor == BrickColor.new("Lime green")
			local userClicked = playerWhoClicked == self.Player
			if not isGreen or not userClicked then return end 

			self.Clicked = true
		end)
	end

	--fires when a player presses a button on their xbox controller
	game.ReplicatedStorage.Remotes.xboxButton.OnServerEvent:Connect(function(player, command, ...)
		self:onXboxButtonPressed(player, command, ...)
	end)
end

-- play punch animations
function _playPunch(character, animationName, speed, button, dummy_model)
	local gloves = character:FindFirstChildOfClass("Model")
	local humanoid = character:FindFirstChild("Humanoid")
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

	animatorRemote:FireClient(player, "Play", animationName, {Priority = 2, Speed=speed})
	wait(.3)

	if animationName == "Left_Hit" then
		game.ReplicatedStorage.Remotes.Sound:FireAllClients("Play", {Name = "LeftPunch", Parent = humanoidRootPart})	
	else
		game.ReplicatedStorage.Remotes.Sound:FireAllClients("Play", {Name = "RightPunch", Parent = humanoidRootPart})	
	end

	wait(0.7)
	animatorRemote:FireClient(player, "Stop", animationName)
end

return PunchDummy

