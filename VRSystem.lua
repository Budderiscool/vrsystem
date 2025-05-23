-- VR System for Roblox
-- Place this script in ServerScriptService

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Create RemoteEvents
local remoteEvents = Instance.new("Folder")
remoteEvents.Name = "VREvents"
remoteEvents.Parent = ReplicatedStorage

local handUpdateEvent = Instance.new("RemoteEvent")
handUpdateEvent.Name = "HandUpdate"
handUpdateEvent.Parent = remoteEvents

local grabEvent = Instance.new("RemoteEvent")
grabEvent.Name = "GrabTool"
grabEvent.Parent = remoteEvents

-- VR Hand Physics and Tool System
local VRSystem = {}
VRSystem.__index = VRSystem

function VRSystem.new(player)
	local self = setmetatable({}, VRSystem)
	self.player = player
	self.character = player.Character or player.CharacterAdded:Wait()
	self.humanoid = self.character:WaitForChild("Humanoid")
	self.rootPart = self.character:WaitForChild("HumanoidRootPart")

	-- Hand parts
	self.leftHand = nil
	self.rightHand = nil
	self.leftHandAttachment = nil
	self.rightHandAttachment = nil

	-- Grabbed tools
	self.leftGrabbedTool = nil
	self.rightGrabbedTool = nil

	-- Physics constraints
	self.leftConstraints = {}
	self.rightConstraints = {}

	self:setupHands()
	self:setupPhysics()

	return self
end

function VRSystem:setupHands()
	-- Create hand parts
	self.leftHand = Instance.new("Part")
	self.leftHand.Name = "LeftVRHand"
	self.leftHand.Size = Vector3.new(0.8, 0.8, 1.2)
	self.leftHand.Material = Enum.Material.Neon
	self.leftHand.BrickColor = BrickColor.new("Bright blue")
	self.leftHand.Shape = Enum.PartType.Ball
	self.leftHand.CanCollide = false
	self.leftHand.Anchored = true
	self.leftHand.Parent = workspace

	self.rightHand = Instance.new("Part")
	self.rightHand.Name = "RightVRHand"
	self.rightHand.Size = Vector3.new(0.8, 0.8, 1.2)
	self.rightHand.Material = Enum.Material.Neon
	self.rightHand.BrickColor = BrickColor.new("Bright red")
	self.rightHand.Shape = Enum.PartType.Ball
	self.rightHand.CanCollide = false
	self.rightHand.Anchored = true
	self.rightHand.Parent = workspace

	-- Create attachments for tools
	self.leftHandAttachment = Instance.new("Attachment")
	self.leftHandAttachment.Name = "HandAttachment"
	self.leftHandAttachment.Parent = self.leftHand

	self.rightHandAttachment = Instance.new("Attachment")
	self.rightHandAttachment.Name = "HandAttachment"
	self.rightHandAttachment.Parent = self.rightHand

	-- Add selection boxes for visual feedback
	local leftSelection = Instance.new("SelectionBox")
	leftSelection.Adornee = self.leftHand
	leftSelection.Color3 = Color3.new(0, 0, 1)
	leftSelection.Transparency = 0.7
	leftSelection.Parent = self.leftHand

	local rightSelection = Instance.new("SelectionBox")
	rightSelection.Adornee = self.rightHand
	rightSelection.Color3 = Color3.new(1, 0, 0)
	rightSelection.Transparency = 0.7
	rightSelection.Parent = self.rightHand
end

function VRSystem:setupPhysics()
	-- Create invisible collision parts for physics
	self.leftCollider = Instance.new("Part")
	self.leftCollider.Name = "LeftHandCollider"
	self.leftCollider.Size = Vector3.new(1, 1, 1)
	self.leftCollider.Transparency = 1
	self.leftCollider.CanCollide = true
	self.leftCollider.Shape = Enum.PartType.Ball
	self.leftCollider.Material = Enum.Material.ForceField
	self.leftCollider.Parent = workspace

	self.rightCollider = Instance.new("Part")
	self.rightCollider.Name = "RightHandCollider"
	self.rightCollider.Size = Vector3.new(1, 1, 1)
	self.rightCollider.Transparency = 1
	self.rightCollider.CanCollide = true
	self.rightCollider.Shape = Enum.PartType.Ball
	self.rightCollider.Material = Enum.Material.ForceField
	self.rightCollider.Parent = workspace

	-- Create BodyPosition for smooth movement
	self.leftBodyPosition = Instance.new("BodyPosition")
	self.leftBodyPosition.MaxForce = Vector3.new(4000, 4000, 4000)
	self.leftBodyPosition.Position = self.leftHand.Position
	self.leftBodyPosition.P = 3000
	self.leftBodyPosition.D = 500
	self.leftBodyPosition.Parent = self.leftCollider

	self.rightBodyPosition = Instance.new("BodyPosition")
	self.rightBodyPosition.MaxForce = Vector3.new(4000, 4000, 4000)
	self.rightBodyPosition.Position = self.rightHand.Position
	self.rightBodyPosition.P = 3000
	self.rightBodyPosition.D = 500
	self.rightBodyPosition.Parent = self.rightCollider

	-- Create BodyAngularVelocity for rotation
	self.leftBodyAngularVelocity = Instance.new("BodyAngularVelocity")
	self.leftBodyAngularVelocity.MaxTorque = Vector3.new(0, math.huge, 0)
	self.leftBodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
	self.leftBodyAngularVelocity.Parent = self.leftCollider

	self.rightBodyAngularVelocity = Instance.new("BodyAngularVelocity")
	self.rightBodyAngularVelocity.MaxTorque = Vector3.new(0, math.huge, 0)
	self.rightBodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
	self.rightBodyAngularVelocity.Parent = self.rightCollider
end

function VRSystem:updateHandPositions(leftCFrame, rightCFrame)
	if self.leftHand and leftCFrame then
		self.leftHand.CFrame = leftCFrame
		self.leftBodyPosition.Position = leftCFrame.Position
	end

	if self.rightHand and rightCFrame then
		self.rightHand.CFrame = rightCFrame
		self.rightBodyPosition.Position = rightCFrame.Position
	end

	-- Update collider positions with slight delay for smooth physics
	if self.leftCollider then
		local leftTarget = self.leftHand.Position
		self.leftCollider.CFrame = self.leftCollider.CFrame:Lerp(CFrame.new(leftTarget), 0.3)
	end

	if self.rightCollider then
		local rightTarget = self.rightHand.Position
		self.rightCollider.CFrame = self.rightCollider.CFrame:Lerp(CFrame.new(rightTarget), 0.3)
	end
end

function VRSystem:grabTool(hand, tool)
	if not tool or not tool.Parent then return end

	local handPart = hand == "Left" and self.leftHand or self.rightHand
	local handAttachment = hand == "Left" and self.leftHandAttachment or self.rightHandAttachment

	if not handPart or not handAttachment then return end

	-- Check if tool has a handle
	local handle = tool:FindFirstChild("Handle")
	if not handle then return end

	-- Create weld constraint
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handPart
	weld.Part1 = handle
	weld.Parent = handPart

	-- Store the grabbed tool
	if hand == "Left" then
		self.leftGrabbedTool = tool
		table.insert(self.leftConstraints, weld)
	else
		self.rightGrabbedTool = tool
		table.insert(self.rightConstraints, weld)
	end

	-- Make tool non-collidable while held
	for _, part in pairs(tool:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
end

function VRSystem:releaseTool(hand)
	local grabbedTool = hand == "Left" and self.leftGrabbedTool or self.rightGrabbedTool
	local constraints = hand == "Left" and self.leftConstraints or self.rightConstraints

	if not grabbedTool then return end

	-- Remove all constraints
	for _, constraint in pairs(constraints) do
		if constraint and constraint.Parent then
			constraint:Destroy()
		end
	end

	-- Clear constraints table
	if hand == "Left" then
		self.leftConstraints = {}
		self.leftGrabbedTool = nil
	else
		self.rightConstraints = {}
		self.rightGrabbedTool = nil
	end

	-- Restore collision
	for _, part in pairs(grabbedTool:GetDescendants()) do
		if part:IsA("BasePart") and part.Name == "Handle" then
			part.CanCollide = true
		end
	end
end

function VRSystem:checkForGrabbableTools(hand)
	local handPart = hand == "Left" and self.leftHand or self.rightHand
	if not handPart then return nil end

	local region = Region3.new(
		handPart.Position - Vector3.new(2, 2, 2),
		handPart.Position + Vector3.new(2, 2, 2)
	)

	-- Find tools near hand
	for _, obj in pairs(workspace:GetPartBoundsInRegion(region, 100)) do
		local tool = obj.Parent
		if tool:IsA("Tool") and (handPart.Position - obj.Position).Magnitude < 3 then
			return tool
		end
	end

	return nil
end

function VRSystem:destroy()
	if self.leftHand then self.leftHand:Destroy() end
	if self.rightHand then self.rightHand:Destroy() end
	if self.leftCollider then self.leftCollider:Destroy() end
	if self.rightCollider then self.rightCollider:Destroy() end
end

-- Player Management
local vrSystems = {}

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		if VRService.VREnabled then
			vrSystems[player] = VRSystem.new(player)
		end
	end)

	player.CharacterRemoving:Connect(function()
		if vrSystems[player] then
			vrSystems[player]:destroy()
			vrSystems[player] = nil
		end
	end)
end

local function onPlayerRemoving(player)
	if vrSystems[player] then
		vrSystems[player]:destroy()
		vrSystems[player] = nil
	end
end

-- Event Handlers
handUpdateEvent.OnServerEvent:Connect(function(player, leftCFrame, rightCFrame)
	local vrSystem = vrSystems[player]
	if vrSystem then
		vrSystem:updateHandPositions(leftCFrame, rightCFrame)
	end
end)

grabEvent.OnServerEvent:Connect(function(player, action, hand)
	local vrSystem = vrSystems[player]
	if not vrSystem then return end

	if action == "grab" then
		local tool = vrSystem:checkForGrabbableTools(hand)
		if tool then
			vrSystem:grabTool(hand, tool)
		end
	elseif action == "release" then
		vrSystem:releaseTool(hand)
	end
end)

-- Connect events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle existing players
for _, player in pairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- Heartbeat connection for physics updates
RunService.Heartbeat:Connect(function()
	for player, vrSystem in pairs(vrSystems) do
		if vrSystem.leftCollider and vrSystem.leftHand then
			-- Smooth collider following
			local leftTarget = vrSystem.leftHand.Position
			vrSystem.leftBodyPosition.Position = leftTarget
		end

		if vrSystem.rightCollider and vrSystem.rightHand then
			local rightTarget = vrSystem.rightHand.Position
			vrSystem.rightBodyPosition.Position = rightTarget
		end
	end
end)
