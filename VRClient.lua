-- VR Client Script (Fixed)
-- Place this script in StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HapticService = game:GetService("HapticService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Wait for remote events
local vrEvents = ReplicatedStorage:WaitForChild("VREvents")
local handUpdateEvent = vrEvents:WaitForChild("HandUpdate")
local grabEvent = vrEvents:WaitForChild("GrabTool")

-- VR Client System
local VRClient = {}
VRClient.__index = VRClient

function VRClient.new()
	local self = setmetatable({}, VRClient)

	self.isVREnabled = VRService.VREnabled
	self.leftHandCFrame = CFrame.new()
	self.rightHandCFrame = CFrame.new()

	-- Input tracking
	self.leftTriggerPressed = false
	self.rightTriggerPressed = false
	self.leftGripPressed = false
	self.rightGripPressed = false

	-- Haptic feedback ready
	self.hapticEnabled = true

	-- Visual feedback
	self.leftHandGui = nil
	self.rightHandGui = nil
	self.screenGui = nil

	-- Force first person camera
	self:setupCamera()

	if self.isVREnabled then
		self:setup()
	else
		self:setupDesktopMode()
	end

	return self
end

function VRClient:setupCamera()
	-- Force first person view
	player.CameraMode = Enum.CameraMode.LockFirstPerson

	-- Wait for character and set camera subject
	if player.Character and player.Character:FindFirstChild("Humanoid") then
		camera.CameraSubject = player.Character.Humanoid
	else
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid")
			camera.CameraSubject = humanoid
		end)
	end
end

function VRClient:setup()
	-- Setup VR input connections
	self:connectVRInputs()
	self:setupVisualFeedback()

	-- Start update loop
	self.heartbeatConnection = RunService.Heartbeat:Connect(function()
		self:updateVR()
	end)
end

function VRClient:setupDesktopMode()
	-- Fallback for non-VR users - use mouse and keyboard
	print("VR not enabled - using desktop mode")

	local mouse = player:GetMouse()
	self:setupVisualFeedback() -- Still show UI for desktop mode

	-- Simple desktop hand simulation
	self.heartbeatConnection = RunService.Heartbeat:Connect(function()
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local rootPart = player.Character.HumanoidRootPart
			local cameraCFrame = camera.CFrame

			-- Simulate hands relative to camera
			self.leftHandCFrame = cameraCFrame * CFrame.new(-1.5, -0.5, -2)
			self.rightHandCFrame = cameraCFrame * CFrame.new(1.5, -0.5, -2)

			-- Move right hand toward mouse direction
			local mouseRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
			local mouseDirection = mouseRay.Direction.Unit
			self.rightHandCFrame = cameraCFrame * CFrame.new(1.5, -0.5, -2) + mouseDirection * 2

			self:sendHandUpdate()
			self:updateVisualFeedback()
		end
	end)

	-- Desktop grab controls
	mouse.Button1Down:Connect(function()
		self.rightTriggerPressed = true
		grabEvent:FireServer("grab", "Right")
	end)

	mouse.Button1Up:Connect(function()
		self.rightTriggerPressed = false
		grabEvent:FireServer("release", "Right")
	end)

	mouse.KeyDown:Connect(function(key)
		if key:lower() == "g" then
			self.leftTriggerPressed = true
			grabEvent:FireServer("grab", "Left")
		end
	end)

	mouse.KeyUp:Connect(function(key)
		if key:lower() == "g" then
			self.leftTriggerPressed = false
			grabEvent:FireServer("release", "Left")
		end
	end)
end

function VRClient:connectVRInputs()
	-- VR controller input
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.Gamepad1 then
			-- Left controller
			if input.KeyCode == Enum.KeyCode.ButtonR2 then -- Left trigger
				self.leftTriggerPressed = true
				grabEvent:FireServer("grab", "Left")
				self:triggerHaptic("Left", 0.5, 0.1)
			elseif input.KeyCode == Enum.KeyCode.ButtonL1 then -- Left grip
				self.leftGripPressed = true
			end
		elseif input.UserInputType == Enum.UserInputType.Gamepad2 then
			-- Right controller
			if input.KeyCode == Enum.KeyCode.ButtonR2 then -- Right trigger
				self.rightTriggerPressed = true
				grabEvent:FireServer("grab", "Right")
				self:triggerHaptic("Right", 0.5, 0.1)
			elseif input.KeyCode == Enum.KeyCode.ButtonL1 then -- Right grip
				self.rightGripPressed = true
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Gamepad1 then
			if input.KeyCode == Enum.KeyCode.ButtonR2 then
				self.leftTriggerPressed = false
				grabEvent:FireServer("release", "Left")
				self:triggerHaptic("Left", 0.3, 0.05)
			elseif input.KeyCode == Enum.KeyCode.ButtonL1 then
				self.leftGripPressed = false
			end
		elseif input.UserInputType == Enum.UserInputType.Gamepad2 then
			if input.KeyCode == Enum.KeyCode.ButtonR2 then
				self.rightTriggerPressed = false
				grabEvent:FireServer("release", "Right")
				self:triggerHaptic("Right", 0.3, 0.05)
			elseif input.KeyCode == Enum.KeyCode.ButtonL1 then
				self.rightGripPressed = false
			end
		end
	end)
end

function VRClient:setupVisualFeedback()
	-- Create GUI feedback for hand tracking
	self.screenGui = Instance.new("ScreenGui")
	self.screenGui.Name = "VRFeedback"
	self.screenGui.ResetOnSpawn = false
	self.screenGui.Parent = player:WaitForChild("PlayerGui")

	-- Left hand indicator
	self.leftHandGui = Instance.new("Frame")
	self.leftHandGui.Size = UDim2.new(0, 40, 0, 40)
	self.leftHandGui.Position = UDim2.new(0, 100, 0.5, -20)
	self.leftHandGui.BackgroundColor3 = Color3.new(0, 0.5, 1)
	self.leftHandGui.BorderSizePixel = 0
	self.leftHandGui.BackgroundTransparency = 0.3
	self.leftHandGui.Parent = self.screenGui

	local leftCorner = Instance.new("UICorner")
	leftCorner.CornerRadius = UDim.new(1, 0)
	leftCorner.Parent = self.leftHandGui

	-- Left hand label
	local leftLabel = Instance.new("TextLabel")
	leftLabel.Size = UDim2.new(1, 0, 1, 0)
	leftLabel.Position = UDim2.new(0, 0, 0, 0)
	leftLabel.BackgroundTransparency = 1
	leftLabel.Text = "L"
	leftLabel.TextColor3 = Color3.new(1, 1, 1)
	leftLabel.TextScaled = true
	leftLabel.Font = Enum.Font.SourceSansBold
	leftLabel.Parent = self.leftHandGui

	-- Right hand indicator
	self.rightHandGui = Instance.new("Frame")
	self.rightHandGui.Size = UDim2.new(0, 40, 0, 40)
	self.rightHandGui.Position = UDim2.new(1, -140, 0.5, -20)
	self.rightHandGui.BackgroundColor3 = Color3.new(1, 0.2, 0.2)
	self.rightHandGui.BorderSizePixel = 0
	self.rightHandGui.BackgroundTransparency = 0.3
	self.rightHandGui.Parent = self.screenGui

	local rightCorner = Instance.new("UICorner")
	rightCorner.CornerRadius = UDim.new(1, 0)
	rightCorner.Parent = self.rightHandGui

	-- Right hand label
	local rightLabel = Instance.new("TextLabel")
	rightLabel.Size = UDim2.new(1, 0, 1, 0)
	rightLabel.Position = UDim2.new(0, 0, 0, 0)
	rightLabel.BackgroundTransparency = 1
	rightLabel.Text = "R"
	rightLabel.TextColor3 = Color3.new(1, 1, 1)
	rightLabel.TextScaled = true
	rightLabel.Font = Enum.Font.SourceSansBold
	rightLabel.Parent = self.rightHandGui
end

function VRClient:updateVR()
	if not self.isVREnabled then return end

	-- Get VR hand positions
	local success1, leftCFrame = pcall(function()
		return UserInputService:GetUserCFrame(Enum.UserCFrame.LeftHand)
	end)

	local success2, rightCFrame = pcall(function()
		return UserInputService:GetUserCFrame(Enum.UserCFrame.RightHand)
	end)

	-- Convert to world space relative to camera
	local cameraCFrame = camera.CFrame

	if success1 and leftCFrame then
		self.leftHandCFrame = cameraCFrame * leftCFrame
	end

	if success2 and rightCFrame then
		self.rightHandCFrame = cameraCFrame * rightCFrame
	end

	-- Send update to server
	self:sendHandUpdate()

	-- Update visual feedback
	self:updateVisualFeedback()
end

function VRClient:sendHandUpdate()
	handUpdateEvent:FireServer(self.leftHandCFrame, self.rightHandCFrame)
end

function VRClient:worldToScreenPoint(worldPosition)
	local screenPoint, onScreen = camera:WorldToScreenPoint(worldPosition)
	return Vector2.new(screenPoint.X, screenPoint.Y), onScreen
end

function VRClient:updateVisualFeedback()
	if not self.leftHandGui or not self.rightHandGui then return end

	-- Update hand GUI positions based on hand world positions
	local leftScreenPos, leftOnScreen = self:worldToScreenPoint(self.leftHandCFrame.Position)
	local rightScreenPos, rightOnScreen = self:worldToScreenPoint(self.rightHandCFrame.Position)

	-- Update positions
	if leftOnScreen then
		self.leftHandGui.Position = UDim2.new(0, leftScreenPos.X - 20, 0, leftScreenPos.Y - 20)
		self.leftHandGui.Visible = true
	else
		self.leftHandGui.Visible = false
	end

	if rightOnScreen then
		self.rightHandGui.Position = UDim2.new(0, rightScreenPos.X - 20, 0, rightScreenPos.Y - 20)
		self.rightHandGui.Visible = true
	else
		self.rightHandGui.Visible = false
	end

	-- Update transparency based on trigger state
	local leftTransparency = self.leftTriggerPressed and 0.1 or 0.5
	local rightTransparency = self.rightTriggerPressed and 0.1 or 0.5

	TweenService:Create(self.leftHandGui, TweenInfo.new(0.1), {BackgroundTransparency = leftTransparency}):Play()
	TweenService:Create(self.rightHandGui, TweenInfo.new(0.1), {BackgroundTransparency = rightTransparency}):Play()
end

function VRClient:triggerHaptic(hand, intensity, duration)
	if not self.hapticEnabled then return end

	pcall(function()
		local inputType = hand == "Left" and Enum.UserInputType.Gamepad1 or Enum.UserInputType.Gamepad2
		local motor = hand == "Left" and Enum.VibrationMotor.Large or Enum.VibrationMotor.Large

		HapticService:SetMotor(inputType, motor, intensity)
		spawn(function()
			wait(duration)
			HapticService:SetMotor(inputType, motor, 0)
		end)
	end)
end

function VRClient:destroy()
	if self.heartbeatConnection then
		self.heartbeatConnection:Disconnect()
	end

	if self.screenGui then
		self.screenGui:Destroy()
	end

	-- Stop any remaining haptic feedback
	pcall(function()
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, 0)
		HapticService:SetMotor(Enum.UserInputType.Gamepad2, Enum.VibrationMotor.Large, 0)
	end)
end

-- Initialize VR client
local vrClient = VRClient.new()

-- Cleanup on player leaving
Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		vrClient:destroy()
	end
end)
