local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VoiceChatService = game:GetService("VoiceChatService")

-- Voice Chat must be enabled in the experience settings by the owner
-- (and available to the player) for the proximity voice scaffold to do anything.

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VoiceChatScaffoldGui"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Parent = playerGui

local function isVoiceEnabled()
	local success, enabled = pcall(function()
		return VoiceChatService:IsVoiceEnabledForUserIdAsync(player.UserId)
	end)

	return success and enabled == true
end

local function makeIndicator()
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0, 0)
	panel.Position = UDim2.new(0.02, 0, 0.02, 0)
	panel.Size = UDim2.new(0.18, 0, 0.05, 0)
	panel.BackgroundColor3 = GameConfig.COLORS.Panel
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = GameConfig.COLORS.AccentDim
	stroke.Transparency = 0.3
	stroke.Parent = panel

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = GameConfig.COLORS.Text
	label.TextScaled = true
	label.Text = "الصوت القريب مفعّل"
	label.Parent = panel
end

if isVoiceEnabled() then
	makeIndicator()
end
