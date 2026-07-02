local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("GatewayToHellRemotes")
local roundStateUpdatedEvent = remotesFolder:WaitForChild("RoundStateUpdated")
local roundOutcomeEvent = remotesFolder:WaitForChild("RoundOutcome")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RoundHUDGui"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 60
screenGui.Parent = playerGui

local chaseMusic = Instance.new("Sound")
chaseMusic.Name = "ChaseMusic"
chaseMusic.SoundId = `rbxassetid://{GameConfig.PLACEHOLDER_SOUND_IDS.ChaseMusic}`
chaseMusic.Looped = true
chaseMusic.Volume = 0
chaseMusic.Parent = SoundService

local heartbeat = Instance.new("Sound")
heartbeat.Name = "HeartbeatLoop"
heartbeat.SoundId = `rbxassetid://{GameConfig.PLACEHOLDER_SOUND_IDS.Heartbeat}`
heartbeat.Looped = true
heartbeat.Volume = 0
heartbeat.Parent = SoundService

local downedLoop = Instance.new("Sound")
downedLoop.Name = "DownedLoop"
downedLoop.SoundId = `rbxassetid://{GameConfig.PLACEHOLDER_SOUND_IDS.DownedLoop}`
downedLoop.Looped = true
downedLoop.Volume = 0

downedLoop.Parent = SoundService

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.new(0.02, 0, 0.10, 0)
panel.Size = UDim2.new(0.30, 0, 0.38, 0)
panel.BackgroundColor3 = GameConfig.COLORS.Panel
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = GameConfig.COLORS.AccentDim
panelStroke.Transparency = 0.18
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0.06, 0, 0.04, 0)
title.Size = UDim2.new(0.88, 0, 0.10, 0)
title.Font = Enum.Font.GothamBlack
title.TextColor3 = GameConfig.COLORS.AccentAlt
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "الجولة"
title.Parent = panel

local timerLabel = Instance.new("TextLabel")
timerLabel.BackgroundTransparency = 1
timerLabel.Position = UDim2.new(0.06, 0, 0.14, 0)
timerLabel.Size = UDim2.new(0.88, 0, 0.09, 0)
timerLabel.Font = Enum.Font.GothamBlack
timerLabel.TextColor3 = GameConfig.COLORS.Text
timerLabel.TextScaled = true
timerLabel.TextXAlignment = Enum.TextXAlignment.Left
timerLabel.Text = "00:00"
timerLabel.Parent = panel

local summaryLabel = Instance.new("TextLabel")
summaryLabel.BackgroundTransparency = 1
summaryLabel.Position = UDim2.new(0.06, 0, 0.23, 0)
summaryLabel.Size = UDim2.new(0.88, 0, 0.07, 0)
summaryLabel.Font = Enum.Font.GothamMedium
summaryLabel.TextColor3 = GameConfig.COLORS.TextMuted
summaryLabel.TextScaled = true
summaryLabel.TextXAlignment = Enum.TextXAlignment.Left
summaryLabel.Text = ""
summaryLabel.Parent = panel

local monsterLabel = Instance.new("TextLabel")
monsterLabel.BackgroundTransparency = 1
monsterLabel.Position = UDim2.new(0.06, 0, 0.30, 0)
monsterLabel.Size = UDim2.new(0.88, 0, 0.06, 0)
monsterLabel.Font = Enum.Font.GothamMedium
monsterLabel.TextColor3 = Color3.fromRGB(255, 122, 84)
monsterLabel.TextScaled = true
monsterLabel.TextXAlignment = Enum.TextXAlignment.Left
monsterLabel.Text = ""
monsterLabel.Parent = panel

local selfPanel = Instance.new("Frame")
selfPanel.BackgroundColor3 = GameConfig.COLORS.PanelSoft
selfPanel.BackgroundTransparency = 0.05
selfPanel.BorderSizePixel = 0
selfPanel.Position = UDim2.new(0.06, 0, 0.37, 0)
selfPanel.Size = UDim2.new(0.88, 0, 0.14, 0)
selfPanel.Parent = panel

local selfCorner = Instance.new("UICorner")
selfCorner.CornerRadius = UDim.new(0, 10)
selfCorner.Parent = selfPanel

local selfStroke = Instance.new("UIStroke")
selfStroke.Color = GameConfig.COLORS.AccentDim
selfStroke.Transparency = 0.35
selfStroke.Parent = selfPanel

local selfStatusTitle = Instance.new("TextLabel")
selfStatusTitle.BackgroundTransparency = 1
selfStatusTitle.Position = UDim2.new(0.05, 0, 0.12, 0)
selfStatusTitle.Size = UDim2.new(0.90, 0, 0.34, 0)
selfStatusTitle.Font = Enum.Font.GothamBlack
selfStatusTitle.TextColor3 = GameConfig.COLORS.Text
selfStatusTitle.TextScaled = true
selfStatusTitle.TextXAlignment = Enum.TextXAlignment.Left
selfStatusTitle.Text = ""
selfStatusTitle.Parent = selfPanel

local selfStatusText = Instance.new("TextLabel")
selfStatusText.BackgroundTransparency = 1
selfStatusText.Position = UDim2.new(0.05, 0, 0.50, 0)
selfStatusText.Size = UDim2.new(0.90, 0, 0.30, 0)
selfStatusText.Font = Enum.Font.GothamMedium
selfStatusText.TextColor3 = GameConfig.COLORS.TextMuted
selfStatusText.TextScaled = true
selfStatusText.TextWrapped = true
selfStatusText.TextXAlignment = Enum.TextXAlignment.Left
selfStatusText.Text = ""
selfStatusText.Parent = selfPanel

local objectivesFrame = Instance.new("Frame")
objectivesFrame.BackgroundTransparency = 1
objectivesFrame.Position = UDim2.new(0.06, 0, 0.54, 0)
objectivesFrame.Size = UDim2.new(0.88, 0, 0.34, 0)
objectivesFrame.Parent = panel

local objectivesLayout = Instance.new("UIListLayout")
objectivesLayout.Padding = UDim.new(0, 4)
objectivesLayout.SortOrder = Enum.SortOrder.LayoutOrder
objectivesLayout.Parent = objectivesFrame

local objectiveRows = {}

local function makeObjectiveRow(index)
	local row = Instance.new("TextLabel")
	row.Name = `Objective{index}`
	row.LayoutOrder = index
	row.BackgroundColor3 = GameConfig.COLORS.PanelSoft
	row.BackgroundTransparency = 0.08
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0.18, 0)
	row.Font = Enum.Font.GothamMedium
	row.TextColor3 = GameConfig.COLORS.Text
	row.TextScaled = true
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextDirection = Enum.TextDirection.RightToLeft
	row.Text = ""
	row.Parent = objectivesFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = row

	local stroke = Instance.new("UIStroke")
	stroke.Color = GameConfig.COLORS.AccentDim
	stroke.Transparency = 0.55
	stroke.Parent = row

	objectiveRows[index] = row
end

for index = 1, 5 do
	makeObjectiveRow(index)
end

local outcomePanel = Instance.new("Frame")
outcomePanel.AnchorPoint = Vector2.new(0.5, 0.5)
outcomePanel.Position = UDim2.fromScale(0.5, 0.5)
outcomePanel.Size = UDim2.new(0.34, 0, 0.2, 0)
outcomePanel.BackgroundColor3 = GameConfig.COLORS.Panel
outcomePanel.BackgroundTransparency = 0.06
outcomePanel.BorderSizePixel = 0
outcomePanel.Visible = false
outcomePanel.Parent = screenGui

local outcomeCorner = Instance.new("UICorner")
outcomeCorner.CornerRadius = UDim.new(0, 16)
outcomeCorner.Parent = outcomePanel

local outcomeStroke = Instance.new("UIStroke")
outcomeStroke.Color = GameConfig.COLORS.Accent
outcomeStroke.Transparency = 0.18
outcomeStroke.Thickness = 2
outcomeStroke.Parent = outcomePanel

local outcomeTitle = Instance.new("TextLabel")
outcomeTitle.BackgroundTransparency = 1
outcomeTitle.Position = UDim2.new(0.06, 0, 0.12, 0)
outcomeTitle.Size = UDim2.new(0.88, 0, 0.28, 0)
outcomeTitle.Font = Enum.Font.GothamBlack
outcomeTitle.TextColor3 = GameConfig.COLORS.AccentAlt
outcomeTitle.TextScaled = true
outcomeTitle.Text = ""
outcomeTitle.Parent = outcomePanel

local outcomeReason = Instance.new("TextLabel")
outcomeReason.BackgroundTransparency = 1
outcomeReason.Position = UDim2.new(0.08, 0, 0.44, 0)
outcomeReason.Size = UDim2.new(0.84, 0, 0.32, 0)
outcomeReason.Font = Enum.Font.GothamMedium
outcomeReason.TextColor3 = GameConfig.COLORS.Text
outcomeReason.TextScaled = true
outcomeReason.TextWrapped = true
outcomeReason.Text = ""
outcomeReason.Parent = outcomePanel

local currentState = nil

local function formatTime(seconds)
	local value = math.max(0, math.floor(tonumber(seconds) or 0))
	local minutes = math.floor(value / 60)
	local remainder = value % 60
	return string.format("%02d:%02d", minutes, remainder)
end

local function formatMonsterLabel(state)
	if not state then
		return ""
	end

	if state.State == "CHASE" then
		if state.TargetUserId == player.UserId then
			return "الحارس يطاردك الآن"
		end
		return "الحارس في مطاردة نشطة"
	elseif state.State == "INVESTIGATE" then
		return "الحارس يحقق في الأثر"
	elseif state.State == "SEARCH" then
		return "الحارس يبحث في القاعة"
	elseif state.State == "PATROL" then
		return "الحارس يتجوّل في الأروقة"
	end

	return ""
end

local function updateObjectives(objectives, gateOpen)
	for index = 1, 5 do
		local row = objectiveRows[index]
		local objective = objectives and objectives[index]
		if objective then
			local prefix = if objective.Solved then "✓ " else ""
			local state = objective.State and objective.State ~= "" and objective.State or ""
			local progress = ` {tonumber(objective.Current) or 0}/{tonumber(objective.Total) or 0}`
			local extra = if state ~= "" and state ~= "solved" then ` • {state}` else ""
			row.Text = `{prefix}{objective.Label}{progress}{extra}`
			row.TextColor3 = if objective.Solved then Color3.fromRGB(255, 180, 110) else GameConfig.COLORS.Text
		else
			row.Text = ""
		end
	end

	if gateOpen then
		summaryLabel.Text = "البوابة مفتوحة، اهرب الآن"
		summaryLabel.TextColor3 = Color3.fromRGB(255, 168, 90)
	else
		summaryLabel.TextColor3 = GameConfig.COLORS.TextMuted
	end
end

local function updateSelfPanel(selfState)
	if not selfState then
		selfPanel.Visible = false
		selfStatusTitle.Text = ""
		selfStatusText.Text = ""
		return
	end

	selfPanel.Visible = true
	local statusLine = ""
	if selfState.State == "Downed" then
		selfStatusTitle.Text = "أنت منطرح"
		selfStatusTitle.TextColor3 = GameConfig.COLORS.Danger
		statusLine = `انتظر الإنقاذ • يفصلك {tonumber(selfState.BleedRemaining) or 0} ثانية عن الموت`
	elseif selfState.State == "Dead" then
		selfStatusTitle.Text = "أنت ميت"
		selfStatusTitle.TextColor3 = Color3.fromRGB(180, 180, 180)
		statusLine = "وضع المشاهدة نشط الآن"
	elseif selfState.State == "Escaped" then
		selfStatusTitle.Text = "نجوت"
		selfStatusTitle.TextColor3 = Color3.fromRGB(255, 180, 110)
		statusLine = "استمر بمراقبة الفريق"
	else
		if currentState and currentState.HuntActive then
			selfStatusTitle.Text = "الحارس يطارد الفريق"
			selfStatusTitle.TextColor3 = Color3.fromRGB(255, 160, 96)
			statusLine = "ابقَ قريبًا من زملائك وراقب الممرات"
		else
			selfStatusTitle.Text = "استعد للجولة"
			selfStatusTitle.TextColor3 = GameConfig.COLORS.Text
			statusLine = ""
		end
	end

	local battery = math.clamp(tonumber(selfState.Battery) or 0, 0, 100)
	local sanity = math.clamp(tonumber(selfState.Sanity) or 0, 0, 100)
	local parts = {
		`البطارية {math.floor(battery)}%`,
		`التركيز {math.floor(sanity)}%`,
	}

	if selfState.Hidden then
		table.insert(parts, "مختبئ")
	end

	if selfState.FlashlightOn then
		table.insert(parts, "المصباح يعمل")
	end

	if selfState.SanityState == "Critical" then
		table.insert(parts, "الهلوسة تقترب")
	elseif selfState.SanityState == "Low" then
		table.insert(parts, "احذر من الظلال")
	end

	if statusLine ~= "" then
		table.insert(parts, 1, statusLine)
	end

	selfStatusText.Text = table.concat(parts, " • ")
end

local function applyAudioAndShake()
	local state = currentState
	local monster = state and state.Monster
	local intensity = 0

	if state and state.HuntActive and monster then
		intensity = math.clamp(tonumber(monster.Intensity) or 0, 0, 1)
	end

	if currentState and currentState.SelfState and currentState.SelfState.State == "Downed" then
		intensity = math.max(intensity, 0.35)
	end

	if intensity > 0 then
		if not chaseMusic.IsPlaying then
			chaseMusic:Play()
		end
		chaseMusic.Volume = math.clamp(0.25 + intensity * 0.55, 0, 0.8)
		if not heartbeat.IsPlaying then
			heartbeat:Play()
		end
		heartbeat.Volume = math.clamp(0.12 + intensity * 0.9, 0, 1)
	else
		chaseMusic.Volume = math.max(0, chaseMusic.Volume - 0.04)
		heartbeat.Volume = math.max(0, heartbeat.Volume - 0.05)
		if chaseMusic.Volume <= 0.01 and chaseMusic.IsPlaying then
			chaseMusic:Stop()
		end
		if heartbeat.Volume <= 0.01 and heartbeat.IsPlaying then
			heartbeat:Stop()
		end
	end

	if currentState and currentState.SelfState and currentState.SelfState.State == "Downed" then
		if not downedLoop.IsPlaying then
			downedLoop:Play()
		end
		downedLoop.Volume = 0.5
	else
		if downedLoop.IsPlaying then
			downedLoop:Stop()
		end
		downedLoop.Volume = 0
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local t = os.clock()
		local shake = intensity * 0.18
		if currentState and currentState.SelfState and currentState.SelfState.State == "Downed" then
			shake = math.max(shake, 0.08)
		end
		humanoid.CameraOffset = Vector3.new(math.sin(t * 26) * shake, math.cos(t * 17) * shake, 0)
	end
end

local function showOutcome(result, reason, endingType)
	currentState = nil
	chaseMusic:Stop()
	heartbeat:Stop()
	downedLoop:Stop()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.CameraOffset = Vector3.new(0, 0, 0)
	end
	panel.Visible = true
	outcomePanel.Visible = true

	local ending = GameConfig.ENDING_LINES.Bad
	if result == "Win" and endingType == "Secret" then
		ending = GameConfig.ENDING_LINES.Secret
	elseif result == "Win" then
		ending = GameConfig.ENDING_LINES.Good
	else
		ending = GameConfig.ENDING_LINES.Bad
	end

	outcomeTitle.Text = ending.TitleAr or ""
	outcomeTitle.TextColor3 = if result == "Win" then Color3.fromRGB(255, 181, 107) else GameConfig.COLORS.Danger
	outcomeReason.Text = ending.LineAr or reason or ""

	TweenService:Create(outcomePanel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.06,
	}):Play()

	task.delay(3, function()
		outcomePanel.Visible = false
		panel.Visible = false
	end)
end

roundStateUpdatedEvent.OnClientEvent:Connect(function(state)
	currentState = state
	if type(state) ~= "table" or not state.Active then
		currentState = nil
		panel.Visible = false
		selfPanel.Visible = false
		monsterLabel.Text = ""
		return
	end

	panel.Visible = true
	title.Text = `الجولة • {state.ModeName or "Story"}`
	timerLabel.Text = formatTime(state.Remaining)
	summaryLabel.Text = state.ObjectiveSummary or ""
	monsterLabel.Text = formatMonsterLabel(state.Monster)
	updateObjectives(state.Objectives, state.GateOpen)
	updateSelfPanel(state.SelfState)

	if state.GateOpen then
		panelStroke.Color = Color3.fromRGB(255, 142, 74)
	else
		panelStroke.Color = GameConfig.COLORS.AccentDim
	end
end)

roundOutcomeEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end

	showOutcome(payload.Result, payload.Reason, payload.EndingType)
end)

RunService.RenderStepped:Connect(function()
	if currentState then
		applyAudioAndShake()
	end
end)
