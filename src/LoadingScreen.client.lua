local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("GatewayToHellRemotes")
local gameReadyEvent = remotesFolder:WaitForChild("GameReady")

pcall(function()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoadingScreenGui"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 1000
screenGui.Parent = playerGui

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1.12, 1.12)
backdrop.Position = UDim2.fromScale(-0.06, -0.06)
backdrop.BackgroundColor3 = GameConfig.COLORS.Background
backdrop.BorderSizePixel = 0
backdrop.Parent = screenGui

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 10, 22)),
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(30, 15, 27)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 6, 10)),
})
gradient.Rotation = 25
gradient.Parent = backdrop

local vignette = Instance.new("Frame")
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundTransparency = 1
vignette.BorderSizePixel = 0
vignette.Parent = screenGui

local vignetteGradient = Instance.new("UIGradient")
vignetteGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 0, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
})
vignetteGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.25),
    NumberSequenceKeypoint.new(0.45, 0.95),
    NumberSequenceKeypoint.new(1, 0.25),
})
vignetteGradient.Parent = vignette

local topGlow = Instance.new("Frame")
topGlow.Size = UDim2.new(1, 0, 0.18, 0)
topGlow.BackgroundColor3 = GameConfig.COLORS.Accent
topGlow.BackgroundTransparency = 0.88
topGlow.BorderSizePixel = 0
topGlow.Parent = screenGui

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0.08, 0, 0.2, 0)
title.Size = UDim2.new(0.84, 0, 0.11, 0)
title.Font = Enum.Font.GothamBlack
title.Text = GameConfig.GameTitleAr
title.TextColor3 = GameConfig.COLORS.AccentAlt
title.TextScaled = true
title.Parent = screenGui

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.new(0.12, 0, 0.31, 0)
subtitle.Size = UDim2.new(0.76, 0, 0.06, 0)
subtitle.Font = Enum.Font.GothamMedium
subtitle.Text = GameConfig.LOADING_MESSAGES.Subtitle
subtitle.TextColor3 = GameConfig.COLORS.TextMuted
subtitle.TextScaled = true
subtitle.Parent = screenGui

local tipLabel = Instance.new("TextLabel")
tipLabel.BackgroundTransparency = 0.15
tipLabel.BackgroundColor3 = GameConfig.COLORS.Panel
tipLabel.BorderSizePixel = 0
tipLabel.Position = UDim2.new(0.12, 0, 0.48, 0)
tipLabel.Size = UDim2.new(0.76, 0, 0.12, 0)
tipLabel.Font = Enum.Font.GothamMedium
tipLabel.TextColor3 = GameConfig.COLORS.Text
tipLabel.TextScaled = true
tipLabel.TextWrapped = true
tipLabel.Parent = screenGui

local tipCorner = Instance.new("UICorner")
tipCorner.CornerRadius = UDim.new(0, 12)
tipCorner.Parent = tipLabel

local progressBack = Instance.new("Frame")
progressBack.AnchorPoint = Vector2.new(0.5, 0.5)
progressBack.Position = UDim2.new(0.5, 0, 0.72, 0)
progressBack.Size = UDim2.new(0.66, 0, 0.034, 0)
progressBack.BackgroundColor3 = GameConfig.COLORS.PanelSoft
progressBack.BorderSizePixel = 0
progressBack.Parent = screenGui

local progressBackCorner = Instance.new("UICorner")
progressBackCorner.CornerRadius = UDim.new(1, 0)
progressBackCorner.Parent = progressBack

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.fromScale(0.12, 1)
progressFill.BackgroundColor3 = GameConfig.COLORS.Accent
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBack

local progressFillCorner = Instance.new("UICorner")
progressFillCorner.CornerRadius = UDim.new(1, 0)
progressFillCorner.Parent = progressFill

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.new(0.18, 0, 0.76, 0)
status.Size = UDim2.new(0.64, 0, 0.05, 0)
status.Font = Enum.Font.GothamSemibold
status.Text = GameConfig.LOADING_MESSAGES.Title
status.TextColor3 = GameConfig.COLORS.TextMuted
status.TextScaled = true
status.Parent = screenGui

local pulse = Instance.new("Frame")
pulse.AnchorPoint = Vector2.new(0.5, 0.5)
pulse.Position = UDim2.new(0.5, 0, 0.53, 0)
pulse.Size = UDim2.new(0.18, 0, 0.18, 0)
pulse.BackgroundColor3 = GameConfig.COLORS.Danger
pulse.BackgroundTransparency = 0.92
pulse.BorderSizePixel = 0
pulse.Parent = screenGui

local pulseCorner = Instance.new("UICorner")
pulseCorner.CornerRadius = UDim.new(1, 0)
pulseCorner.Parent = pulse

local progressValue = 0
local ready = false
local fadePlayed = false
local tipIndex = 1
local loreIndex = 1

local function updateTip()
    local tip = GameConfig.SURVIVAL_TIPS[tipIndex]
    local lore = GameConfig.MONSTER_LORE[loreIndex]
    tipLabel.Text = `{tip}\n{lore}`
    tipIndex = (tipIndex % #GameConfig.SURVIVAL_TIPS) + 1
    loreIndex = (loreIndex % #GameConfig.MONSTER_LORE) + 1
end

local function tweenProgress(target)
    local tween = TweenService:Create(progressFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(target, 1),
    })
    tween:Play()
end

local function fadeOut()
    if fadePlayed then
        return
    end

    fadePlayed = true

    for _, guiObject in ipairs(screenGui:GetDescendants()) do
        if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") then
            local tween = TweenService:Create(guiObject, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundTransparency = 1,
                TextTransparency = 1,
            })
            tween:Play()
        elseif guiObject:IsA("Frame") then
            local tween = TweenService:Create(guiObject, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundTransparency = 1,
            })
            tween:Play()
        elseif guiObject:IsA("UIGradient") then
            guiObject.Enabled = false
        end
    end

    task.delay(0.45, function()
        screenGui:Destroy()
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
        end)
    end)
end

gameReadyEvent.OnClientEvent:Connect(function()
    ready = true
    status.Text = "تم تجهيز القاعة الرئيسية."
    progressValue = 1
    tweenProgress(1)
    task.delay(0.35, fadeOut)
end)

task.spawn(function()
    while screenGui.Parent do
        if not ready then
            progressValue = math.min(progressValue + 0.03, 0.94)
            tweenProgress(progressValue)
            status.Text = `جارٍ التهيئة... {math.floor(progressValue * 100)}%`
        end

        updateTip()
        local driftX = math.sin(os.clock() * 0.12) * 0.015
        local driftY = math.cos(os.clock() * 0.09) * 0.02
        backdrop.Position = UDim2.fromScale(-0.06 + driftX, -0.06 + driftY)
        pulse.BackgroundTransparency = 0.88 + (math.sin(os.clock() * 2) + 1) * 0.025
        task.wait(2.2)
    end
end)
