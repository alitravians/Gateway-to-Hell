local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("GatewayToHellRemotes")
local openChoiceEvent = remotesFolder:WaitForChild("OpenMatchmakingChoice")
local submitChoiceEvent = remotesFolder:WaitForChild("SubmitMatchmakingChoice")
local countdownEvent = remotesFolder:WaitForChild("QueueCountdown")
local teleportEvent = remotesFolder:WaitForChild("TeleportAnnounced")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MatchmakingGui"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 50
screenGui.Parent = playerGui

local selectionPanel = Instance.new("Frame")
selectionPanel.AnchorPoint = Vector2.new(0.5, 0.5)
selectionPanel.Position = UDim2.fromScale(0.5, 0.63)
selectionPanel.Size = UDim2.new(0.34, 0, 0.46, 0)
selectionPanel.BackgroundColor3 = GameConfig.COLORS.Panel
selectionPanel.BackgroundTransparency = 0.08
selectionPanel.BorderSizePixel = 0
selectionPanel.Visible = false
selectionPanel.Parent = screenGui

local selectionCorner = Instance.new("UICorner")
selectionCorner.CornerRadius = UDim.new(0, 14)
selectionCorner.Parent = selectionPanel

local selectionStroke = Instance.new("UIStroke")
selectionStroke.Color = GameConfig.COLORS.AccentDim
selectionStroke.Transparency = 0.15
selectionStroke.Parent = selectionPanel

local selectionTitle = Instance.new("TextLabel")
selectionTitle.BackgroundTransparency = 1
selectionTitle.Position = UDim2.new(0.06, 0, 0.04, 0)
selectionTitle.Size = UDim2.new(0.88, 0, 0.12, 0)
selectionTitle.Font = Enum.Font.GothamBlack
selectionTitle.TextColor3 = GameConfig.COLORS.AccentAlt
selectionTitle.Text = "اختر وضع اللعب"
selectionTitle.TextScaled = true
selectionTitle.Parent = selectionPanel

local selectionInfo = Instance.new("TextLabel")
selectionInfo.BackgroundTransparency = 1
selectionInfo.Position = UDim2.new(0.08, 0, 0.15, 0)
selectionInfo.Size = UDim2.new(0.84, 0, 0.08, 0)
selectionInfo.Font = Enum.Font.GothamMedium
selectionInfo.TextColor3 = GameConfig.COLORS.TextMuted
selectionInfo.Text = "اختر الوضع ثم عدد اللاعبين للانضمام إلى البوابة."
selectionInfo.TextScaled = true
selectionInfo.TextWrapped = true
selectionInfo.Parent = selectionPanel

local selectedModeLabel = Instance.new("TextLabel")
selectedModeLabel.BackgroundTransparency = 1
selectedModeLabel.Position = UDim2.new(0.08, 0, 0.24, 0)
selectedModeLabel.Size = UDim2.new(0.84, 0, 0.06, 0)
selectedModeLabel.Font = Enum.Font.GothamMedium
selectedModeLabel.TextColor3 = GameConfig.COLORS.AccentAlt
selectedModeLabel.TextScaled = true
selectedModeLabel.Text = "وضع اللعب: غير محدد"
selectedModeLabel.Parent = selectionPanel

local modeContainer = Instance.new("Frame")
modeContainer.BackgroundTransparency = 1
modeContainer.Position = UDim2.new(0.08, 0, 0.32, 0)
modeContainer.Size = UDim2.new(0.84, 0, 0.34, 0)
modeContainer.Parent = selectionPanel

local modeLayout = Instance.new("UIGridLayout")
modeLayout.CellPadding = UDim2.new(0, 8, 0, 8)
modeLayout.CellSize = UDim2.new(0.48, 0, 0.48, 0)
modeLayout.FillDirectionMaxCells = 2
modeLayout.SortOrder = Enum.SortOrder.LayoutOrder
modeLayout.Parent = modeContainer

local countLabel = Instance.new("TextLabel")
countLabel.BackgroundTransparency = 1
countLabel.Position = UDim2.new(0.08, 0, 0.67, 0)
countLabel.Size = UDim2.new(0.84, 0, 0.06, 0)
countLabel.Font = Enum.Font.GothamMedium
countLabel.TextColor3 = GameConfig.COLORS.TextMuted
countLabel.TextScaled = true
countLabel.Text = "اختر فريقك"
countLabel.Parent = selectionPanel

local buttonContainer = Instance.new("Frame")
buttonContainer.BackgroundTransparency = 1
buttonContainer.Position = UDim2.new(0.08, 0, 0.74, 0)
buttonContainer.Size = UDim2.new(0.84, 0, 0.18, 0)
buttonContainer.Parent = selectionPanel

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.Padding = UDim.new(0, 8)
buttonLayout.FillDirection = Enum.FillDirection.Horizontal
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonLayout.Parent = buttonContainer

local selectedModeId = GameConfig.DEFAULT_MODE_ID
local modeButtons = {}

local function applyModeSelection(modeId)
	selectedModeId = modeId
	for id, button in pairs(modeButtons) do
		button.BackgroundColor3 = if id == modeId then GameConfig.COLORS.Accent else GameConfig.COLORS.AccentDim
	end

	local mode = GameConfig.getModeById(modeId)
	if mode then
		selectedModeLabel.Text = `وضع اللعب: {mode.NameAr}`
		selectionInfo.Text = mode.DescriptionAr
	else
		selectedModeLabel.Text = "وضع اللعب: غير محدد"
	end
end

local function makeModeButton(mode)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0.48, 0, 0.48, 0)
	button.BackgroundColor3 = GameConfig.COLORS.AccentDim
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.Text = mode.NameAr
	button.TextColor3 = GameConfig.COLORS.Text
	button.TextScaled = true
	button.Parent = modeContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	button.MouseButton1Click:Connect(function()
		applyModeSelection(mode.Id)
	end)

	modeButtons[mode.Id] = button
end

local function makeCountButton(count)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0.29, 0, 1, 0)
	button.BackgroundColor3 = GameConfig.COLORS.AccentDim
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBlack
	button.Text = tostring(count)
	button.TextColor3 = GameConfig.COLORS.Text
	button.TextScaled = true
	button.Parent = buttonContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	button.MouseButton1Click:Connect(function()
		if not selectedModeId then
			selectionInfo.Text = "اختر وضع اللعب أولًا"
			return
		end
		submitChoiceEvent:FireServer({
			ModeId = selectedModeId,
			PlayerCount = count,
		})
		selectionPanel.Visible = false
	end)

end

for _, mode in ipairs(GameConfig.GAME_MODES) do
	makeModeButton(mode)
end

for _, count in ipairs(GameConfig.PLAYER_COUNT_OPTIONS) do
	makeCountButton(count)
end

applyModeSelection(GameConfig.DEFAULT_MODE_ID)

local countdownOverlay = Instance.new("Frame")
countdownOverlay.Size = UDim2.fromScale(1, 1)
countdownOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
countdownOverlay.BackgroundTransparency = 0.45
countdownOverlay.BorderSizePixel = 0
countdownOverlay.Visible = false
countdownOverlay.Parent = screenGui

local countdownText = Instance.new("TextLabel")
countdownText.AnchorPoint = Vector2.new(0.5, 0.5)
countdownText.Position = UDim2.fromScale(0.5, 0.5)
countdownText.Size = UDim2.new(0.36, 0, 0.18, 0)
countdownText.BackgroundTransparency = 1
countdownText.Font = Enum.Font.GothamBlack
countdownText.TextColor3 = GameConfig.COLORS.AccentAlt
countdownText.TextScaled = true
countdownText.Text = ""
countdownText.Parent = countdownOverlay

local countdownPulse = Instance.new("UIStroke")
countdownPulse.Color = GameConfig.COLORS.Accent
countdownPulse.Thickness = 2
countdownPulse.Transparency = 0.4
countdownPulse.Parent = countdownText

openChoiceEvent.OnClientEvent:Connect(function(payload)
	selectionPanel.Visible = true
	if type(payload) == "table" and payload.Modes then
		selectionInfo.Text = "اختر الوضع ثم العدد للانضمام إلى الجولة."
	end
end)

countdownEvent.OnClientEvent:Connect(function(payload)
	countdownOverlay.Visible = true
	if type(payload) == "table" then
		if payload.Remaining and payload.Remaining > 0 then
			countdownText.Text = `جاري الانطلاق خلال {payload.Remaining}`
		else
			countdownText.Text = `الانطلاق الآن • {payload.ModeId or "Story"}`
		end
	else
		countdownText.Text = "جاري الانطلاق..."
	end

	TweenService:Create(countdownText, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	}):Play()
end)

teleportEvent.OnClientEvent:Connect(function()
	countdownText.Text = "نقل اللاعبين..."
	task.delay(1, function()
		countdownOverlay.Visible = false
	end)
end)
