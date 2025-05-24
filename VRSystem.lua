-- VR System for Roblox (Fixed)
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

	-- Hand positions for smoothing
	self.leftTargetCFrame = CFrame.new()
	self.rightTargetCFrame = CFrame.new()

	self:setupHands()
	self:setupPhysics()

	return self
end

function VRSystem:setupHands()
	-- Create hand parts (smaller and more hand-like)
	self.leftHand = Instance.new("Part")
	self.leftHand.Name = "LeftVRHand"
	self.leftHand.Size = Vector3.new(0.6, 0.3, 1)
	self.leftHand.Material = Enum.Material.ForceField
	self.leftHand.BrickColor = BrickColor.new("Bright blue")
	self.leftHand.Shape = Enum.PartType.Block
	self.leftHand.CanCollide = false
	self.leftHand.Anchored = false
	self.leftHand.Parent = workspace

	self.rightHand = Instance.new("Part")
	self.rightHand.Name = "RightVRHand"
	self.rightHand.Size = Vector3.new(0.6, 0.3, 1)
	self.rightHand.Material = Enum.Material.ForceField
	self.rightHand.BrickColor = BrickColor.new("Bright red")
	self.rightHand.Shape = Enum.PartType.Block
	self.rightHand.CanCollide = false
	self.rightHand.Anchored = false
	self.rightHand.Parent = workspace

	-- Round the corners
	local leftCorner = Instance.new("SpecialMesh")
	leftCorner.MeshType = Enum.MeshType.Brick
	leftCorner.Parent = self.leftHand

	local rightCorner = Instance.new("SpecialMesh")
	rightCorner.MeshType = Enum.MeshType.Brick
	rightCorner.Parent = self.rightHand

	-- Create attachments for tools
	self.leftHandAttachment = Instance.new("Attachment")
	self.leftHandAttachment.Name = "HandAttachment"
	self.leftHandAttachment.Parent = self.leftHand

	self.rightHandAttachment = Instance.new("Attachment")
	self.rightHandAttachment.Name = "HandAttachment"
	self.rightHandAttachment.Parent = self.rightHand

	-- Add glowing effect
	local leftPointLight = Instance.new("PointLight")
	leftPointLight.Brightness = 1
	leftPointLight.Color = Color3.new(0, 0, 1)
	leftPointLight.Range = 5
	leftPointLight.Parent = self.leftHand

	local rightPointLight = Instance.new("PointLight")
	rightPointLight.Brightness = 1
	rightPointLight.Color = Color3.new(1, 0, 0)
	rightPointLight.Range = 5
	rightPointLight.Parent = self.rightHand
end

function VRSystem:setupPhysics()
	-- Create BodyPosition for smooth movement with less jitter
	self.leftBodyPosition = Instance.new("BodyPosition")
	self.leftBodyPosition.MaxForce = Vector3.new(12000, 12000, 12000)
	self.leftBodyPosition.Position = self.leftHand.Position
	self.leftBodyPosition.P = 8000  -- Higher P for more responsiveness
	self.leftBodyPosition.D = 2000  -- Higher D for less oscillation
	self.leftBodyPosition.Parent = self.leftHand

	self.rightBodyPosition = Instance.new("BodyPosition")
	self.rightBodyPosition.MaxForce = Vector3.new(12000, 12000, 12000)
	self.rightBodyPosition.Position = self.rightHand.Position
	self.rightBodyPosition.P = 8000
	self.rightBodyPosition.D = 2000
	self.rightBodyPosition.Parent = self.rightHand

	-- Create BodyAngularVelocity for rotation with less jitter
	self.leftBodyAngularVelocity = Instance.new("BodyAngularVelocity")
	self.leftBodyAngularVelocity.MaxTorque = Vector3.new(8000, 8000, 8000)
	self.leftBodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
	self.leftBodyAngularVelocity.P = 3000
	self.leftBodyAngularVelocity.Parent = self.leftHand

	self.rightBodyAngularVelocity = Instance.new("BodyAngularVelocity")
	self.rightBodyAngularVelocity.MaxTorque = Vector3.new(8000, 8000, 8000)
	self.rightBodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
	self.rightBodyAngularVelocity.P = 3000
	self.rightBodyAngularVelocity.Parent = self.rightHand

	-- Remove BodyVelocity as it can cause conflicts
end

function VRSystem:updateHandPositions(leftCFrame, rightCFrame)
	if self.leftHand and leftCFrame then
		self.leftTargetCFrame = leftCFrame
		-- Direct position update for less lag
		self.leftBodyPosition.Position = leftCFrame.Position

		-- Simplified rotation handling to reduce jitter
		local currentRotation = self.leftHand.CFrame - self.leftHand.CFrame.Position
		local targetRotation = leftCFrame - leftCFrame.Position
		local rotationDifference = currentRotation:Inverse() * targetRotation

		local axis, angle = rotationDifference:ToAxisAngle()
		if angle > 0.01 then
			-- Smooth angular velocity for less jitter
			self.leftBodyAngularVelocity.AngularVelocity = axis * math.min(angle * 5, 10)
		else
			self.leftBodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
		end
	end

	if self.rightHand and rightCFrame then
		self.rightTargetCFrame = rightCFrame
		-- Direct position update for less lag
		self.rightBodyPosition.Position = rightCFrame.Position

		-- Simplified rotation handling to reduce jitter
		local currentRotation = self.rightHand.CFrame - self.rightHand.CFrame.Position
		local targetRotation = rightCFrame - rightCFrame.Position
		local rotationDifference = currentRotation:Inverse() * targetRotation

		local axis, angle = rotationDifference:ToAxisAngle()
		if angle > 0.01 then
			-- Smooth angular velocity for less jitter
			self.rightBodyAngularVelocity.AngularVelocity = axis * math.min(angle * 5, 10)
		else
			self.rightBodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
		end
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

	-- Release any currently held tool first
	self:releaseTool(hand)

	-- Create a more stable connection using WeldConstraint
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handPart
	weld.Part1 = handle
	weld.Parent = handPart

	-- Also add Motor6D for extra stability with tools
	local motor = Instance.new("Motor6D")
	motor.Name = "HandMotor"
	motor.Part0 = handPart
	motor.Part1 = handle
	motor.C0 = CFrame.new(0, 0, 0) -- Offset can be adjusted per tool
	motor.Parent = handPart

	-- Store the grabbed tool and constraints
	if hand == "Left" then
		self.leftGrabbedTool = tool
		table.insert(self.leftConstraints, weld)
		table.insert(self.leftConstraints, motor)
	else
		self.rightGrabbedTool = tool
		table.insert(self.rightConstraints, weld)
		table.insert(self.rightConstraints, motor)
	end

	-- Disable collision for tool parts to prevent physics conflicts
	for _, part in pairs(tool:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			-- Also reduce mass to prevent physics issues
			if part ~= handle then
				part.Massless = true
			end
		end
	end

	-- Make handle massless too for better physics
	handle.Massless = true

	-- Visual feedback - make hand glow brighter when holding something
	local light = handPart:FindFirstChild("PointLight")
	if light then
		TweenService:Create(light, TweenInfo.new(0.2), {Brightness = 2}):Play()
	end

	print(self.player.Name .. " grabbed " .. tool.Name .. " with " .. hand .. " hand")
end

function VRSystem:releaseTool(hand)
	local grabbedTool = hand == "Left" and self.leftGrabbedTool or self.rightGrabbedTool
	local constraints = hand == "Left" and self.leftConstraints or self.rightConstraints
	local handPart = hand == "Left" and self.leftHand or self.rightHand

	if not grabbedTool then return end

	-- Remove all constraints
	for _, constraint in pairs(constraints) do
		if constraint and constraint.Parent then
			constraint:Destroy()
		end
	end

	-- Clear constraints table and grabbed tool
	if hand == "Left" then
		self.leftConstraints = {}
		self.leftGrabbedTool = nil
	else
		self.rightConstraints = {}
		self.rightGrabbedTool = nil
	end

	-- Restore collision and mass properties for tool parts
	for _, part in pairs(grabbedTool:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = true
			part.Massless = false
		end
	end

	-- Give the tool a small velocity based on hand movement to make dropping feel natural
	local handle = grabbedTool:FindFirstChild("Handle")
	if handle and handPart then
		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
		bodyVelocity.Velocity = handPart.Velocity * 0.5 -- Inherit some hand velocity
		bodyVelocity.Parent = handle

		-- Remove the velocity after a short time
		game:GetService("Debris"):AddItem(bodyVelocity, 0.5)
	end

	-- Visual feedback - dim hand light
	local light = handPart:FindFirstChild("PointLight")
	if light then
		TweenService:Create(light, TweenInfo.new(0.2), {Brightness = 1}):Play()
	end

	print(self.player.Name .. " released " .. grabbedTool.Name .. " from " .. hand .. " hand")
end

function VRSystem:checkForGrabbableTools(hand)
	local handPart = hand == "Left" and self.leftHand or self.rightHand
	if not handPart then return nil end

	local searchRadius = 3
	local nearestTool = nil
	local nearestDistance = math.huge

	-- Search for tools in workspace
	for _, obj in pairs(workspace:GetChildren()) do
		if obj:IsA("Tool") then
			local handle = obj:FindFirstChild("Handle")
			if handle then
				local distance = (handPart.Position - handle.Position).Magnitude
				if distance < searchRadius and distance < nearestDistance then
					nearestTool = obj
					nearestDistance = distance
				end
			end
		end
	end

	-- Also check player's backpack for tools
	if not nearestTool and self.player.Backpack then
		for _, tool in pairs(self.player.Backpack:GetChildren()) do
			if tool:IsA("Tool") then
				-- Spawn tool in world for VR grabbing
				tool.Parent = workspace
				local handle = tool:FindFirstChild("Handle")
				if handle then
					handle.CFrame = handPart.CFrame * CFrame.new(0, 0, -1)
					return tool
				end
			end
		end
	end

	return nearestTool
end

function VRSystem:destroy()
	-- Clean up grabbed tools
	self:releaseTool("Left")
	self:releaseTool("Right")

	-- Clean up parts
	if self.leftHand then self.leftHand:Destroy() end
	if self.rightHand then self.rightHand:Destroy() end
end

-- Player Management
local vrSystems = {}

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		-- Small delay to ensure character is fully loaded
		wait(1)
		vrSystems[player] = VRSystem.new(player)
		print("VR System created for " .. player.Name)
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

-- Heartbeat connection for smooth physics updates
RunService.Heartbeat:Connect(function()
	for player, vrSystem in pairs(vrSystems) do
		if vrSystem.leftHand and vrSystem.rightHand then
			-- Reduce additional smoothing since we already smooth on client
			-- Just ensure the BodyPosition targets are up to date
			if vrSystem.leftTargetCFrame then
				vrSystem.leftBodyPosition.Position = vrSystem.leftTargetCFrame.Position
			end

			if vrSystem.rightTargetCFrame then
				vrSystem.rightBodyPosition.Position = vrSystem.rightTargetCFrame.Position
			end
		end
	end
end)
