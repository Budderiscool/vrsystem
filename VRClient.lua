-- VR Client Script
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

	if self.isVREnabled then
		self:setup()
	else
		self:setupDesktopMode()
	end

	return self
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

	-- Simple desktop hand simulation
	self.heartbeatConnection = RunService.Heartbeat:Connect(function()
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local rootPart = player.Character.HumanoidRootPart
			local mouseCFrame = CFrame.new(mouse.Hit.Position)

			-- Simulate hands near mouse position
			self.leftHandCFrame = rootPart.CFrame * CFrame.new(-2, 0, -3) * CFrame.Angles(0, math.rad(-30), 0)
			self.rightHandCFrame = mouseCFrame * CFrame.new(1, 1, 0)

			self:sendHandUpdate()
		end
	end)

	-- Desktop grab controls
	mouse.Button1Down:Connect(function()
		grabEvent:FireServer("grab", "Right")
	end)

	mouse.Button1Up:Connect(function()
		grabEvent:FireServer("release", "Right")
	end)

	mouse.KeyDown:Connect(function(key)
		if key:lower() == "g" then
			grabEvent:FireServer("grab", "Left")
		end
	end)

	mouse.KeyUp:Connect(function(key)
		if key:lower() == "g" then
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

function VRClient:setupHaptics()
	-- Haptics are handled by HapticService - no setup needed
	self.hapticEnabled = true
end

function VRClient:setupVisualFeedback()
	-- Create GUI feedback for grabbing
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "VRFeedback"
	screenGui.Parent = player:WaitForChild("PlayerGui")

	-- Left hand indicator
	self.leftHandGui = Instance.new("Frame")
	self.leftHandGui.Size = UDim2.new(0, 50, 0, 50)
	self.leftHandGui.Position = UDim2.new(0, 50, 0, 50)
	self.leftHandGui.BackgroundColor3 = Color3.new(0, 0, 1)
	self.leftHandGui.BorderSizePixel = 0
	self.leftHandGui.BackgroundTransparency = 0.7
	self.leftHandGui.Parent = screenGui

	local leftCorner = Instance.new("UICorner")
	leftCorner.CornerRadius = UDim.new(1, 0)
	leftCorner.Parent = self.leftHandGui

	-- Right hand indicator
	self.rightHandGui = Instance.new("Frame")
	self.rightHandGui.Size = UDim2.new(0, 50, 0, 50)
	self.rightHandGui.Position = UDim2.new(1, -100, 0, 50)
	self.rightHandGui.BackgroundColor3 = Color3.new(1, 0, 0)
	self.rightHandGui.BorderSizePixel = 0
	self.rightHandGui.BackgroundTransparency = 0.7
	self.rightHandGui.Parent = screenGui

	local rightCorner = Instance.new("UICorner")
	rightCorner.CornerRadius = UDim.new(1, 0)
	rightCorner.Parent = self.rightHandGui
end

function VRClient:updateVR()
	if not self.isVREnabled then return end

	-- Get VR hand positions
	local leftCFrame, leftSize = UserInputService:GetUserCFrame(Enum.UserCFrame.LeftHand)
	local rightCFrame, rightSize = UserInputService:GetUserCFrame(Enum.UserCFrame.RightHand)
	local headCFrame = UserInputService:GetUserCFrame(Enum.UserCFrame.Head)

	-- Convert to world space
	local cameraCFrame = camera.CFrame

	if leftCFrame then
		self.leftHandCFrame = cameraCFrame * leftCFrame
	end

	if rightCFrame then
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

function VRClient:updateVisualFeedback()
	if not self.leftHandGui or not self.rightHandGui then return end

	-- Update hand GUI transparency based on trigger state
	local leftTransparency = self.leftTriggerPressed and 0.2 or 0.7
	local rightTransparency = self.rightTriggerPressed and 0.2 or 0.7

	TweenService:Create(self.leftHandGui, TweenInfo.new(0.1), {BackgroundTransparency = leftTransparency}):Play()
	TweenService:Create(self.rightHandGui, TweenInfo.new(0.1), {BackgroundTransparency = rightTransparency}):Play()
end

function VRClient:triggerHaptic(hand, intensity, duration)
	if not self.hapticEnabled then return end

	pcall(function()
		if hand == "Left" then
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.LeftHand, intensity)
			spawn(function()
				wait(duration)
				HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.LeftHand, 0)
			end)
		else
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand, intensity)
			spawn(function()
				wait(duration)
				HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand, 0)
			end)
		end
	end)
end

function VRClient:destroy()
	if self.heartbeatConnection then
		self.heartbeatConnection:Disconnect()
	end

	-- Stop any remaining haptic feedback
	pcall(function()
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.LeftHand, 0)
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.RightHand, 0)
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
