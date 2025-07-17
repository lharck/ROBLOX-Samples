--[[
 Class template for any exercise in which the user clicks and performs a set number of reps
]]
 
DefaultExercise = {}
DefaultExercise.__index = DefaultExercise

local sharedModules = game.ReplicatedStorage:WaitForChild("SharedModules")
local serverUtils = game.ServerScriptService:WaitForChild("ServerUtilities")
local Data = require(sharedModules:WaitForChild("PlayerDataModule"))
local xpModule = require(serverUtils:WaitForChild("awardXP"))
local animatorRemote = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AnimatorRemote")

-- constructor for default exercise
function DefaultExercise.new(model)
	local self = {}
	setmetatable(self, DefaultExercise)

	self.Model = model
	
	local properties = model.Properties
	
	-- Properties relating to general machine operation
	self.ExerciseType = properties.ExerciseType.Value
	self.Prompt = properties.Prompt.Value
	self.AnimationName = properties.AnimationName.Value
	self.Stat = properties.Stat.Value
	self.UseGloves = properties.UseGloves.Value
	self.NumReps = properties.NumReps.Value
	
	self.Player = nil

	return self
end

-- Start the exercise for a player
function DefaultExercise:Start(player, endExercise)
	self.Player = player
	local character = player.Character
	
	self:_GiveCosmetics()
	animatorRemote:FireClient(player, "Play", self.AnimationName)

	-- Do reps, awarding XP for each rep
	for i = 1, self.NumReps do
		task.wait(0.75)
		xpModule.awardXP(self.Player, self.Stat, 1)
		task.wait(0.75)
	end

	animatorRemote:FireClient(player, "Stop", self.AnimationName)
	self:_RemoveCosmetics()
end

-- Give the player the any cosmetics for this exercise
function DefaultExercise:_GiveCosmetics()
	self:_SetAllItemsTransparency(1) -- Hide any equipment used during the exercise 
	
	for _, item in ipairs(self.Model.Properties.Items:GetChildren()) do
		local itemModel = self.Model:FindFirstChild(item.Value):Clone() -- Get equipment model
		itemModel.Parent = self.Player.Character
		self:_WeldEquipment(itemModel, item.BodyPart.Value, item.Attach.Value) -- Attach equipment to player
		self:_SetModelTransparency(itemModel, 0) -- Show equipment
	end
end

-- Remove all cosmetics for this exercise
function DefaultExercise:_RemoveCosmetics()
	for _, item in ipairs(self.Model.Properties.Items:GetChildren()) do
		self:_SetItemTransparency(item.Value, item.Visible.Value and 0 or 1) -- Show equipment where necessary
		
		-- Remove equipment
		if self.Player then
			local characterItem = self.Player.Character:FindFirstChild(item.Value)		
			if characterItem then characterItem:Destroy() end
		end
	end
end

-- Clean up the exercise after it has been completed
-- for garbage collection
function DefaultExercise:Clean()
	self.Player = nil
	self:_RemoveCosmetics()
end

-- Weld the equipment model to the player's body part
function DefaultExercise:_WeldEquipment(equipmentModel, bodyPartName, cframe)
	self:_WeldModelToGrip(equipmentModel) -- Weld model
	self:_SetModelAnchored(equipmentModel, false) -- Unanchor
	
	-- Weld to body part
	local weld = Instance.new("Weld", equipmentModel:FindFirstChild("Grip"))
	weld.Part0 = self.Player.Character:FindFirstChild(bodyPartName)
	weld.Part1 = equipmentModel:FindFirstChild("Grip")
	weld.C0 = cframe
end

-- Weld all parts of the model to the grip part
function DefaultExercise:_WeldModelToGrip(model)
	local grip = model:FindFirstChild("Grip")

	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			local weld = Instance.new("Weld", grip)
			weld.C0 = grip.CFrame:inverse() * child.CFrame
			weld.Part0 = grip
			weld.Part1 = child
		end
	end
end

-- Set whether the model is anchored or not
function DefaultExercise:_SetModelAnchored(model, setting)
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			child.Anchored = setting
		end
	end
end

-- Set the transparency of all items in the exercise model
function DefaultExercise:_SetAllItemsTransparency(transparency)
	for _, item in ipairs(self.Model.Properties.Items:GetChildren()) do
		self:_SetItemTransparency(item.Value, transparency)
	end
end

-- Set the transparency of a specific item in the exercise model
function DefaultExercise:_SetItemTransparency(itemName, transparency)
	local item = self.Model:FindFirstChild(itemName)
	
	if item then
		self:_SetModelTransparency(item, transparency)
	end
end

-- Set the transparency of all parts in a model
function DefaultExercise:_SetModelTransparency(model, transparency)
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			child.Transparency = transparency
		end
	end
end

return DefaultExercise

