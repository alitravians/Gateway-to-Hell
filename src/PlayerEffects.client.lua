local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("GatewayToHellRemotes")
local roundStateUpdatedEvent = remotesFolder:WaitForChild("RoundStateUpdated")
local toggleFlashlightRequest = remotesFolder:WaitForChild("ToggleFlashlightRequest")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlayerEffectsGui"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 55
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(0.98, 0, 0.10, 0)
panel.Size = UDim2.new(0.18, 0, 0.14, 0)
panel.BackgroundColor3 = GameConfig.COLORS.Panel
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = GameConfig.COLORS.AccentDim
panelStroke.Transparency = 0.25
panelStroke.Parent = panel

local batteryLabel = Instance.new("TextLabel")
batteryLabel.BackgroundTransparency = 1
batteryLabel.Position = UDim2.new(0.08, 0, 0.10, 0)
batteryLabel.Size = UDim2.new(0.84, 0, 0.32, 0)
batteryLabel.Font = Enum.Font.GothamBold
batteryLabel.TextColor3 = GameConfig.COLORS.Text
batteryLabel.TextScaled = true
batteryLabel.TextXAlignment = Enum.TextXAlignment.Left
batteryLabel.Text = "البطارية 100%"
batteryLabel.Parent = panel

local sanityLabel = Instance.new("TextLabel")
sanityLabel.BackgroundTransparency = 1
sanityLabel.Position = UDim2.new(0.08, 0, 0.46, 0)
sanityLabel.Size = UDim2.new(0.84, 0, 0.32, 0)
sanityLabel.Font = Enum.Font.GothamBold
sanityLabel.TextColor3 = GameConfig.COLORS.TextMuted
sanityLabel.TextScaled = true
sanityLabel.TextXAlignment = Enum.TextXAlignment.Left
sanityLabel.Text = "التركيز 100%"
sanityLabel.Parent = panel

local hintLabel = Instance.new("TextLabel")
hintLabel.BackgroundTransparency = 1
hintLabel.Position = UDim2.new(0.08, 0, 0.76, 0)
hintLabel.Size = UDim2.new(0.84, 0, 0.16, 0)
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.TextColor3 = GameConfig.COLORS.AccentAlt
hintLabel.TextScaled = true
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Text = "F • المصباح"
hintLabel.Parent = panel

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(20, 0, 0)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel = 0
overlay.Parent = screenGui

local overlayStroke = Instance.new("UIStroke")
overlayStroke.Color = Color3.fromRGB(255, 68, 48)
overlayStroke.Thickness = 6
overlayStroke.Transparency = 1
overlayStroke.Parent = overlay

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Name = "GatewaySanityCorrection"
colorCorrection.Parent = Lighting

local blur = Instance.new("BlurEffect")
blur.Name = "GatewaySanityBlur"
blur.Size = 0
blur.Parent = Lighting

local whispers = Instance.new("Sound")
whispers.Name = "SanityWhispers"
whispers.SoundId = `rbxassetid://{GameConfig.PLACEHOLDER_SOUND_IDS.Whispers}`
whispers.Looped = true
whispers.Volume = 0
whispers.Parent = screenGui

local currentState = nil

local function clamp01(value)
	return math.clamp(tonumber(value) or 0, 0, 1)
end

local function updateDisplay(selfState)
	local battery = math.clamp(tonumber(selfState and selfState.Battery) or 0, 0, 100)
	local sanity = math.clamp(tonumber(selfState and selfState.Sanity) or 0, 0, 100)
	batteryLabel.Text = `البطارية {math.floor(battery)}%`
	sanityLabel.Text = `التركيز {math.floor(sanity)}%`

	if selfState and selfState.Hidden then
		hintLabel.Text = "مختبئ • F للمصباح"
	else
		hintLabel.Text = "F • المصباح"
	end
end

local function applySanityEffects(selfState)
	local sanity = math.clamp(tonumber(selfState and selfState.Sanity) or 100, 0, 100)
	local huntActive = currentState and currentState.HuntActive
	local lowFactor = math.clamp((45 - sanity) / 45, 0, 1)
	local criticalFactor = math.clamp((25 - sanity) / 25, 0, 1)

	colorCorrection.Saturation = -0.15 - lowFactor * 0.7
	colorCorrection.Contrast = 0.05 + lowFactor * 0.35
	colorCorrection.Brightness = -0.04 - lowFactor * 0.06
	colorCorrection.TintColor = Color3.fromRGB(255, math.floor(255 - lowFactor * 18), math.floor(255 - lowFactor * 22))

	blur.Size = lowFactor * 5 + criticalFactor * 7
	if huntActive then
		blur.Size += 0.6
	end

	if sanity <= 35 or (huntActive and sanity <= 55) then
		if not whispers.IsPlaying then
			whispers:Play()
		end
		whispers.Volume = math.clamp(0.06 + criticalFactor * 0.2, 0, 0.25)
	else
		whispers.Volume = math.max(0, whispers.Volume - 0.04)
		if whispers.Volume <= 0.01 and whispers.IsPlaying then
			whispers:Stop()
		end
	end

	local overlayOpacity = math.clamp(lowFactor * 0.28 + criticalFactor * 0.18, 0, 0.4)
	overlay.BackgroundTransparency = 1 - overlayOpacity
	overlayStroke.Transparency = 1 - overlayOpacity * 1.6
end

roundStateUpdatedEvent.OnClientEvent:Connect(function(state)
	if type(state) ~= "table" or not state.Active then
		currentState = nil
		panel.Visible = false
		overlay.BackgroundTransparency = 1
		overlayStroke.Transparency = 1
		colorCorrection.Saturation = 0
		colorCorrection.Contrast = 0
		colorCorrection.Brightness = 0
		blur.Size = 0
		if whispers.IsPlaying then
			whispers:Stop()
		end
		return
	end

	currentState = state
	panel.Visible = true
	updateDisplay(state.SelfState)
	applySanityEffects(state.SelfState)
end)

ContextActionService:BindAction(
	"ToggleFlashlight",
	function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end

		local state = currentState
		if not state or not state.SelfState or state.SelfState.State ~= "Alive" or state.SelfState.Hidden then
			return Enum.ContextActionResult.Pass
		end

		toggleFlashlightRequest:FireServer()
		return Enum.ContextActionResult.Sink
	end,
	false,
	Enum.KeyCode.F
)

RunService.RenderStepped:Connect(function()
	if currentState then
		applySanityEffects(currentState.SelfState)
	end
end)
